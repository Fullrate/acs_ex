defmodule ACS.Session do
  use GenServer
  use Prometheus.Metric
  require Logger

  @moduledoc """

    The actual ACS-CPE session is handled here. A session is initiated
    when an Inform arrives, therefore the init function takes a parsed
    Inform request as an argument.

    We let the supervisor handle the main session handler, and then we
    register new sessions with the session_begins method

  """

  @doc """

    For the supervisor.

  """
  def start_link([spec_module],session_id,device_id,message,fun \\ nil) do
    Logger.debug("ACS.Session start_link(#{inspect session_id},#{inspect device_id}")
    Gauge.inc([name: :acs_ex_nof_sessions, labels: [device_id.product_class]])
    GenServer.start_link(__MODULE__, [spec_module,session_id,device_id,message,fun])
  end

  # API

  @doc """

    when stuff is sent into this session, like CWMP messages
    or other stuff.

  """
  def process_message(session_id, message) do
    try do
      timeout=case Application.fetch_env(:acs_ex, :session_timeout) do
        {:ok, to} -> to
        :error -> 30000
      end
      GenServer.call(via_tuple(session_id), {:process_message, [session_id,message]}, timeout)
    catch
      # timeout comes as :exit, reason.
      :exit, reason -> case reason do
        {:timeout,_} -> # Generate fault response? Or maybee just end the session by returning ""
                        # Will it depend on the state of things?
                        msg = hd(message)
                        CWMP.Protocol.Generator.generate(
                          %CWMP.Protocol.Messages.Header{id: msg.header.id},
                          %CWMP.Protocol.Messages.Fault{faultcode: "Server", faultstring: "CWMP fault", detail:
                            %CWMP.Protocol.Messages.FaultStruct{code: "8002", string: "Internal error"}})
        {what,ever} -> {what,ever}
      end
    end
  end

  @doc """

  When something non-Inform'ish is sent into the session we need to find and verify the
  session.

  """
  def verify_session(session_id, remote_host) do
    try do
      timeout=case Application.fetch_env(:acs_ex, :session_timeout) do
        {:ok, to} -> to
        :error -> 30000
      end
      case GenServer.call(via_tuple(session_id), {:verify_remotehost, [remote_host]}, timeout) do
        {:noproc, _} -> false
        host_verify_result -> host_verify_result
      end
    catch
      # timeout comes as :exit, reason.
      :exit, _reason -> false
    end
  end

  @doc """

    Script message. This means the a scripting process wants a response to a request
    we just put the request in the plug queue and answer no_reply here.

  """
  def script_command(device_id, command) do
    # put it into the script_element
    Logger.debug("API script_command called...#{inspect device_id}, #{inspect command}")
    try do
      timeout=case Application.fetch_env(:acs_ex, :script_timeout) do
        {:ok, to} -> to
        :error -> 29000
      end
      Logger.debug("API script_command got timeout value: #{timeout}")
      GenServer.call(via_tuple(device_id), {:script_command, [command]}, timeout)
    catch
      :exit, reason -> case reason do
        {:timeout,_} -> # reply with timeout
                        Logger.debug("API script_command timeout occured!")
                        {:error, "timeout"}
        {what,ever} -> Logger.debug("Whatever occured #{inspect what}, #{inspect ever}")
                       {what,ever}
      end
    end
  end

  defp takeover_session(session_id, tries \\ 5)

  defp takeover_session(_session_id, 0), do: {:error, "Could not take over session"}
  defp takeover_session(session_id, tries) do
    case :gproc.reg_or_locate({:n, :l, {:session_id, session_id}}) do
      {other, _} when other == self() ->
        :ok
      {other, _} ->
        ref = Process.monitor(other)
        Process.exit(other, :kill) # TODO: Maybe send a poison pill?
        receive do
          {:DOWN, _ref, :process, _other, _} -> takeover_session(session_id, tries-1)
        after
          1000 ->
            Process.demonitor(ref, :flush)
            takeover_session(session_id, tries-1)
        end
    end
  end

  # SERVER

  def init([script_module,session_id,device_id,message,fun]) do
    # This should only be called when the Plug gets an Inform, it this up
    # to me to check, or the caller? I will assume caller.

    # This conn.body_params must be a parsed Inform, if not - ignore
    # Queue the response in the plug_element, so that it can be popped with next response
    # InformResponse into the plug queue

    Logger.metadata(serial: device_id.serial_number, sessionid: session_id)
    gspid=self()
    sspid=spawn_link(__MODULE__, :session_prestart, [gspid, script_module, device_id, hd(message.entries), session_id, fun]) # TODO: Should be "first inform encountered", not just hd

    # Start session script process, save pid to state
    case takeover_session(session_id) do
      :ok ->
        Process.flag(:trap_exit, true)
        {:ok,%{device_id: device_id, session_id: session_id, script_element: nil, plug_element: nil, unmatched_incomming_list: [], sspid: sspid, cwmp_version: message.cwmp_version}}
      _ -> {:stop, "Could not take over session"}
    end
  end

  @doc """

  Used for :trap_exit

  1. signal with reply/2 that this is over
  2. kill me?

  """
  def handle_info({:EXIT, _pid, _reason}, state) do
    ## Session Script is done.
    Logger.debug("Script system exited.")
    case state.plug_element do
      nil ->
        Logger.debug( "Session script exited, and we have no waiting plug, leave the plug some time to end session" )
      pe ->
        # Waiting plug, we have to tell it to stop by sending {204,""}
        Logger.debug("Waiting plug when SS ends, just tell it to stop, which in turn will kill me (the session)")
        GenServer.reply( pe.from, {204, ""} )
    end
    {:noreply,%{state | plug_element: nil, script_element: nil, sspid: nil}, 5000}
  end

  def handle_info(:timeout, state) do
    # Kill self...
    Logger.warn("Session died due to timeout")
    # Update the Prometheus metrics
    Counter.inc([name: :acs_ex_dead_sessions, labels: [state.device_id.product_class]])
    {:stop, :timeout, state}
  end

  def handle_info(message, state) do
    Logger.error("Unhandled handle_info(#{inspect message}, #{inspect state})")
  end

  def terminate(reason, state) do
    Logger.debug("Session terminate called: #{inspect reason}, #{inspect state}")
    Gauge.dec([name: :acs_ex_nof_sessions, labels: [state.device_id.product_class]])
    :normal
  end

  def handle_call({:script_command, [command]}, from, state) do
    Logger.debug("handle_call(:script_command, [#{inspect(command)}])")

    case state.plug_element do
      %{message: _msg, from: plug_from, state: :waiting} ->
        # A plug is waiting when a scripting function has not ended, and the plug is ready for more requests
        # meaning it received "" from a CPE indicating that the CPE has nothing more. We keep waiting
        # because the scripting system is supposed to introduce new reqeusts, that is its purpose, and
        # as long as it is not dead, we must expect more.
        Logger.debug("Session Script discovered a waiting plug. Sending scripted command at once!")
        case gen_request(command.method, command.args, "script", state.cwmp_version) do
          {:ok,{id,req}} ->
            GenServer.reply(plug_from, {200, req})
            {:noreply, %{state | plug_element: nil, script_element: %{command: command, from: from, state: :sent, id: id}}}
          {:error,msg} ->
            # some error should be returned to "from" who is the SS
            {:reply, {:error, msg}, %{state | script_element: nil}}
        end

      _ ->
        Logger.debug( "No known plug_element, meaning no plug is waiting, so store script command in state" )
        # Just put the command in the script element, we wont affect the plug queue until the
        # session reaches the "what now?" stage (empty request from device)
        case state.script_element do
          nil ->
            {:noreply, %{state | script_element: %{command: command, from: from, state: :unhandled}}}
          _ ->
            Logger.error("Unable to handle multiple scripting commands at the time.")
            {:reply, :error, state}
        end

    end
  end

  @doc """

  verifies the remote_host by comparing it to the one in the state.device_id

  """
  def handle_call({:verify_remotehost, [remote_host]}, _from, state) do
    {:reply, state.device_id.ip == remote_host, state}
  end

  @doc """

  Processes a message from the plug. "message" is the CWMP.Protocol version of
  the parsed request sent into the plug.

  """
  def handle_call({:process_message, [session_id,message]}, from, state) do
    Logger.debug("handle_call(:process_message, #{session_id}, #{inspect(message)})")

    # If this message is an Inform, it can be ignored, because the response to that
    # has already been queue in the plug_element by init.
    # If this message is empty, it means that the session is about to end, unless
    # we have something more to send.

    # Anything else means that the front element in the script_element must be responsible for
    # this thing arriving, and the script is currently awaiting this reply, so we must :reply
    # now.
    {plug,script,unmatched,sspid} = case length(Map.keys(message)) do
      0 ->
        # Empty message here. This means examine the script_element to see if there are
        # any new scripted message to push into the plug queue. If nothing can be found,
        # push "" into the plug_element - ending the session. The Plug should kill it...
        Logger.debug("Empty message discovered: sspid: #{inspect state.sspid}, script_element: #{inspect(state.script_element)}")
        case state.script_element do
          nil ->
            # nothing in the script thing, we can end the session... if the session script process has exited.
            Logger.debug("No script_element")
            case state.sspid do
              nil ->
                # no session script
                Logger.debug("No script pid")
                {{204,""},nil,[],state.sspid} # we can stop...
              sspid ->
                # Session script is going, but no element?? Maybee this is before it could queue
                # or maybee its in some long operation
                if Process.alive?(sspid) do
                  Logger.debug("Script system IS alive ....")
                  # If we have an :unscripted waiting, reply now
                  {:noreply,nil,state.unmatched_incomming_list,sspid}
                else
                  Logger.debug("Script system is not actually alive, it only seems so. Missed an :exit?")
                  {{204,""},nil,[],nil}
                end
            end

          %{command: :unscripted, from: script_from, state: :unhandled} ->
            Logger.debug("Replying to :unscripted command")
            GenServer.reply(script_from, state.unmatched_incomming_list)
            {:noreply,nil,[],state.sspid}

          %{command: command, from: script_from, state: :unhandled} ->
            # And unhandled message from script?
            Logger.debug("There is a script element")
            # Transform the command to a plug_element thing, and mark it :sent
            case gen_request(command.method, command.args, "script", state.cwmp_version) do
              {:ok,{id,req}} ->
                {{200,req}, %{command: command, from: script_from, state: :sent, id: id}, state.unmatched_incomming_list, state.sspid}
              {:error,msg} ->
                Logger.debug("gen_request error: #{msg}")
                # must send reply to SS with error, even though this should never happen,
                # then we must continue to wait in the plug
                GenServer.reply(script_from, {:error, msg})
                {:noreply,nil,state.unmatched_incomming_list,state.sspid}
            end

          _ ->
            Logger.debug("Cant identify script_element, clearing and discontinuing session: #{inspect(state.script_element)}")
            {{204,""},nil,[],nil}
        end

      3 ->
        Logger.debug("CWMP message discovered: script_element: #{inspect(state.script_element)}")
        # This could be a response that has to go to script land. In fact if the script_element
        # is empty this is weird and should be ignored and logged.

        # Could be that message is an Inform, in which case we just generate an InformResponse and dont stack anything in the plug element.
        case has_inform?(message.entries) do
          true ->
            Logger.debug("Session server saw inform, generating response")
            id = if !is_nil(message.header) && Map.has_key?(message.header, :id) do
              message.header.id
            else
              0
            end

            {{200,CWMP.Protocol.Generator.generate!(
               %CWMP.Protocol.Messages.Header{id: id},
               %CWMP.Protocol.Messages.InformResponse{max_envelopes: 1}, message.cwmp_version)},state.script_element,[],state.sspid}
          false ->
            case state.script_element do
              nil ->
                Logger.debug("Incomming non-inform message with no script element...")
                # what? - ignore that......or queue it somewhere in state if someone wants it")
                # Stuff the message into the junk list - the list of unsolicited messages.
                # We should still respond...
                {reply,msg} = construct_reply( message )
                if state.sspid != nil and Process.alive?(state.sspid) do
                  Logger.debug("Script pid found to be alive")
                  {reply, nil, msg, state.sspid}
                else
                  Logger.debug("Script pid found to be dead")
                  {reply, nil, msg, nil}
                end

              %{command: :unscripted, from: _from, state: :unhandled} ->
                Logger.debug("We have a script wanting the unmatched list - we should still reply to this though")
                {reply,msg} = construct_reply( message )
                {reply,state.script_element,msg,state.sspid}

              # This only matches script elements that have acutally been sent to the CPE
              # If we have a script element waiting for the session to enter into a state
              # where we can send it, we will no come here on any autonomous
              # CPE message lige TransferComplete...
              %{command: _command, from: from, state: :sent, id: generated_header_id} ->
                # Check if the incomming message matches the one generated
                # by the script system - this can be done by ID comparison

                # Compare ID of incomming to ID of scripted message
                if ( message.header.id == generated_header_id ) do
                  Logger.debug("Incomming message is meant for script")
                  GenServer.reply(from, message)
                  # We have nothing to reply with here, so we must stuff this in OutstandingPlug and
                  # wait for someting from the Script, either next message or :EXIT
                  # we have to answer :noreply here, and
                  {:noreply, nil, state.unmatched_incomming_list, state.sspid}
                else
                  Logger.debug("Incomming message is unmatched to script - we should reply somehow?")
                  # If this is a Response to a CPE request, then we have to end the session at once with
                  # a Fault.
                  # If on the other hand this is an arbitrary request from a CPE, stack it in the unmatched
                  # list and :reply with an appropriate response from here.

                  # Generate a response for every message in the envelope.
                  # TODO: Generate response for every message in entries and wrap
                  # it in one envelope. This can be done by using CMWP.Protocol.Generate.generate(req)
                  # directly, or expanding cwmp_ex to include the capacity to take a list of
                  # entries.
                  {reply,msg} = construct_reply( message )
                  {reply,state.script_element,msg,state.sspid}
                end
              # In this case, then the incomming request can not be a response, and must
              # be stored into the junk list
              %{command: _command, from: _from, state: :unhandled} ->
                {reply,msg} = construct_reply( message )
                if state.sspid != nil and Process.alive?(state.sspid) do
                  Logger.debug("Script pid found to be alive")
                  {reply, state.script_element, msg, state.sspid}
                else
                  Logger.debug("Script pid found to be dead")
                  {reply, nil, msg, nil}
                end
            end
          end

      _ ->
        Logger.debug("Unknown message discovered - ignored")
        {state.plug_element, state.script_element, state.sspid}
    end

    Logger.debug("process_message returning with #{inspect plug}, #{inspect script}, #{inspect unmatched} #{inspect sspid}")
    case plug do
      :noreply -> {:noreply, %{state | plug_element: %{message: message, from: from, state: :waiting}, unmatched_incomming_list: state.unmatched_incomming_list ++ unmatched, sspid: sspid}}
      _ -> {:reply, plug, %{state | script_element: script, unmatched_incomming_list: state.unmatched_incomming_list ++ unmatched, sspid: sspid}}
    end
  end

  def handle_call(request,from,state) do
    super(request,from,state)
  end

  def has_inform?([]), do: false
  def has_inform?([%CWMP.Protocol.Messages.Inform{} | _]), do: true
  def has_inform?([_ | es]), do: has_inform?(es)

  @doc """
  this is spawn_linked and should `apply` the call to the module
  """
  def session_prestart(gspid,script_module,device_id,message,sessionid,fun) do
    # Set the metadata for the scripting process
    Logger.metadata(sessionid: sessionid, serial: device_id.serial_number)
    case fun do
      nil -> case script_module do
        nil -> Logger.error("Impossible to start a session with no script module or function")
        spec_mod -> apply(spec_mod, :session_start, [gspid, device_id, message])
      end
      f when is_function(f) -> apply(fun, [gspid, device_id, message])
      _ -> Logger.error("Can not figure out how to call the session_start function")
    end
  end

  # PRIVATE METHODS

  defp via_tuple(session_id) do
    {:via, :gproc, {:n, :l, {:session_id, session_id}}}
  end

  defp construct_reply( message ) do
    entry = hd(message.entries)
    id = cond do
      Map.has_key?(message, :header) && message.header != nil ->
        message.header.id
      true ->
        0
    end

    case message_type(entry) do
      {:cpe,_messagetype} ->
        # ...Response and that type
        # just respond with {} since responses should
        # be always "handled" here..
        {{204,""},[message]}
      {:acs,CWMP.Protocol.Messages.GetRPCMethods} ->
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: id},
          %CWMP.Protocol.Messages.GetRPCMethodsResponse{methods: ["GetRPCMethods","Inform","TransferComplete","AutonomousTransferComplete","Kicked","RequestDownload","DUStateChangeComplete","AutonomousDUStateChangeComplete"]},message.cwmp_version)},[message]}
      {:acs,CWMP.Protocol.Messages.TransferComplete} ->
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: id},
          %CWMP.Protocol.Messages.TransferCompleteResponse{},message.cwmp_version)},[message]}
      {:acs,CWMP.Protocol.Messages.AutonomousTransferComplete} ->
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: id},
          %CWMP.Protocol.Messages.AutonomousTransferCompleteResponse{},message.cwmp_version)},[message]}
      {:acs,CWMP.Protocol.Messages.Kicked} ->
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: id},
          %CWMP.Protocol.Messages.KickedResponse{next_url: entry.next},message.cwmp_version)},[message]}
      {:acs,CWMP.Protocol.Messages.RequestDownload} ->
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: id},
          %CWMP.Protocol.Messages.RequestDownloadResponse{},message.cwmp_version)},[message]}
      {:acs,CWMP.Protocol.Messages.DUStateChangeComplete} ->
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: id},
          %CWMP.Protocol.Messages.DUStateChangeCompleteResponse{},message.cwmp_version)},[message]}
      {:acs,CWMP.Protocol.Messages.AutonomousDUStateChangeComplete} ->
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: id},
          %CWMP.Protocol.Messages.AutonomousDUStateChangeCompleteResponse{},message.cwmp_version)},[message]}

      _ ->
        # unknown message type, what to do? - Fault back?
        {{204,""},[message]}
    end
  end

  defp message_type( entry ) do
    case entry do
      %CWMP.Protocol.Messages.GetRPCMethods{} -> {:acs,entry.__struct__}
      %CWMP.Protocol.Messages.Inform{} -> {:acs,entry.__struct__}
      %CWMP.Protocol.Messages.TransferComplete{} -> {:acs,entry.__struct__}
      %CWMP.Protocol.Messages.AutonomousTransferComplete{} -> {:acs,entry.__struct__}
      %CWMP.Protocol.Messages.Kicked{} -> {:acs,entry.__struct__}
      %CWMP.Protocol.Messages.RequestDownload{} -> {:acs,entry.__struct__}
      %CWMP.Protocol.Messages.DUStateChangeComplete{} -> {:acs,entry.__struct__}
      %CWMP.Protocol.Messages.AutonomousDUStateChangeComplete{} -> {:acs,entry.__struct__}

      %CWMP.Protocol.Messages.SetParameterValuesResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.GetParameterValuesResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.GetParameterNamesResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.SetParameterAttributesResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.GetParameterAttributesResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.AddObjectResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.DeleteObjectResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.DownloadResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.RebootResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.GetQueuedTransfersResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.ScheduleInformResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.SetVouchersResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.GetOptionsResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.UploadResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.FactoryResetResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.GetAllQueuedTransfersResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.ScheduleDownloadResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.CancelTransferResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.ChangeDUStateResponse{} -> {:cpe,entry.__struct__}
      %CWMP.Protocol.Messages.Fault{} -> {:cpe,entry.__struct__}

      _ -> {:unknown,entry.__struct__}
    end
  end

  # interpret queue data, transform to appropriate CWMP.Protocol.Messages. struct and
  # ask CWMP.Protocol to generate
  defp gen_request(method,args,_source,cwmp_version) do
    Logger.debug("gen_request: #{method}")
    case validateArgs(method,args) do
      true ->
        id=generateID()
        header=%CWMP.Protocol.Messages.Header{id: id}
        message=case method do
          "GetRPCMethods" ->
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.GetRPCMethods{}, cwmp_version)
          "SetParameterValues" ->
            params=for a <- args, do: %CWMP.Protocol.Messages.ParameterValueStruct{name: a.name, type: a.type, value: a.value}
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.SetParameterValues{parameters: params}, cwmp_version)
          "GetParameterValues" ->
            params=for a <- args, do: %CWMP.Protocol.Messages.GetParameterValuesStruct{name: a, type: "string"}
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.GetParameterValues{parameters: params}, cwmp_version)
          "GetParameterNames" ->
            params=%CWMP.Protocol.Messages.GetParameterNames{parameter_path: args.parameter_path, next_level: args.next_level}
            CWMP.Protocol.Generator.generate!(header, params, cwmp_version)
          "SetParameterAttributes" ->
            params=for a <- args, do: %CWMP.Protocol.Messages.SetParameterAttributesStruct{
              name: a.name,
              notification_change: a.notification_change,
              notification: a.notification,
              accesslist_change: a.accesslist_change,
              accesslist: a.accesslist
            }
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.SetParameterAttributes{parameters: params}, cwmp_version)
          "GetParameterAttributes" ->
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.GetParameterAttributes{parameters: args}, cwmp_version)
          "AddObject" ->
            CWMP.Protocol.Generator.generate!(header, struct(CWMP.Protocol.Messages.AddObject, args), cwmp_version)
          "DeleteObject" ->
            CWMP.Protocol.Generator.generate!(header, struct(CWMP.Protocol.Messages.DeleteObject, args), cwmp_version)
          "Reboot" ->
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.Reboot{}, cwmp_version)
          "Download" ->
            CWMP.Protocol.Generator.generate!(header, struct(CWMP.Protocol.Messages.Download, args), cwmp_version)
          "GetQueuedTransfers" ->
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.GetQueuedTransfers{}, cwmp_version)
          "ScheduleInform" ->
            CWMP.Protocol.Generator.generate!(header, struct(CWMP.Protocol.Messages.ScheduleInform, args), cwmp_version)
          "SetVouchers" ->
            voucherlist=for xmlsig <- args, do: struct(CWMP.Protocol.Messages.XMLSignatureStruct, xmlsig)
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.SetVouchers{voucherlist: voucherlist}, cwmp_version)
          "GetOptions" ->
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.GetOptions{option_name: args}, cwmp_version)
          "Upload" ->
            CWMP.Protocol.Generator.generate!(header, struct(CWMP.Protocol.Messages.Upload, args), cwmp_version)
          "FactoryReset" ->
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.FactoryReset{}, cwmp_version)
          "GetAllQueuedTransfers" ->
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.GetAllQueuedTransfers{}, cwmp_version)
          "ScheduleDownload" ->
            CWMP.Protocol.Generator.generate!(header, struct(CWMP.Protocol.Messages.ScheduleDownload, args), cwmp_version)
          "CancelTransfer" ->
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.CancelTransfer{commandkey: args}, cwmp_version)
          "ChangeDUState" ->
            CWMP.Protocol.Generator.generate!(header, struct(CWMP.Protocol.Messages.ChangeDUState, args), cwmp_version)
          _ ->
            {:error,"Cant match request method: #{method}"}
        end
        {:ok,{id,message}}
      false -> {:error,"arguments for request #{method} do not validate"}
    end
  end

  defp validateArgs(method,args) do
    case method do
      "GetRPCMethods" ->
        true # No args for this one
      "SetParameterValues" ->
        # args must be list of maps with name,type and value keys
        case args do
          l when is_list(l) and length(l) > 0 ->
            Enum.all?(args, fn(a) -> Map.has_key?(a,:name) && Map.has_key?(a,:type) && Map.has_key?(a,:value) end)
          _ ->
            false
        end
      "GetParameterValues" ->
        # args must be map with name and type key in all elements
        case args do
          l when is_list(l) and length(l) > 0 ->
            Enum.all?(args, fn(a) -> String.valid?(a) end)
          _ ->
            false
        end
      "GetParameterNames" ->
        # args must be map with path and next_level keys
        is_map(args) and Map.has_key?(args,:parameter_path) and Map.has_key?(args,:next_level)
      "SetParameterAttributes" ->
        # args must be map with path and next_level keys
        case args do
          l when is_list(l) and length(l) > 0 ->
            Enum.all?(args, fn(a) -> Map.has_key?(a,:name) and Map.has_key?(a,:notification_change) and Map.has_key?(a,:notification) and Map.has_key?(a,:accesslist_change) and Map.has_key?(a,:accesslist) and is_list(a.accesslist) end)
          _ ->
            false
        end
      "GetParameterAttributes" ->
        # args must be list of string, at least 1 element in list
        is_list(args) and length(args) > 0 and String.valid?(hd(args))
      "AddObject" ->
        # args must be map with at least key "object_name" and value must end in .
        if is_map(args) and Map.has_key?(args,:object_name) do
          String.last(args.object_name) == "."
        else
          false
        end
      "DeleteObject" ->
        # args must be map with at least key "object_name" and value must end in .
        if is_map(args) and Map.has_key?(args,:object_name) do
          String.last(args.object_name) == "."
        else
          false
        end
      "Reboot" ->
        true # takes no params, always true
      "Download" ->
        is_map(args) and Map.has_key?(args,:url) and Map.has_key?(args,:filesize) and Map.has_key?(args,:filetype)
      "GetQueuedTransfers" ->
        true # takes no params, always true
      "ScheduleInform" ->
        # args is a map with "commandkey" and "delay_seconds"
        if is_map(args) and Map.has_key?(args,:commandkey) and Map.has_key?(args,:delay_seconds) do
          if is_integer(args.delay_seconds) do
            true
          else
            Integer.parse(args.delay_seconds) != :error
          end
        else
          false
        end
      "SetVouchers" ->
        # args is a list of maps with keys
        #  signature_value:
        #  key_info
        #    key_value
        #      dsa_p
        #      dsa_q
        #      dsa_g
        #      dsa_y
        #    x509_data
        #      issuer_serial
        #        issuer_name
        #        serial_number
        #     subject_name
        #     certificates []
        #  options, list of maps with
        #    v_serial_num
        #    deviceid
        #      manufacturer
        #      oui
        #      product_class
        #      serial_number
        #    option_ident
        #    option_desc
        #    start_date (Timex.DateTime)
        #    duration
        #    duration_units
        #    mode
        #    sha1_digest
        if is_list(args) do
          Enum.all?(args,fn(a) ->
            if Map.has_key?(a,:signature_value) and Map.has_key?(a,:key_info) and Map.has_key?(a,:options) do
              Logger.debug("step1")
              if is_list(a.options) and length(a.options)>0 and Map.has_key?(a.key_info,:key_value) and Map.has_key?(a.key_info,:x509_data) do
                Logger.debug("step2")
                if Map.has_key?(a.key_info.key_value,:dsa_p) and Map.has_key?(a.key_info.key_value,:dsa_q) and Map.has_key?(a.key_info.key_value,:dsa_g) and Map.has_key?(a.key_info.key_value,:dsa_y) do
                  Logger.debug("step3")
                  if Map.has_key?(a.key_info.x509_data,:issuer_serial) and Map.has_key?(a.key_info.x509_data,:subject_name) and Map.has_key?(a.key_info.x509_data,:certificates) and is_list(a.key_info.x509_data.certificates) and Map.has_key?(a.key_info.x509_data.issuer_serial,:issuer_name) and Map.has_key?(a.key_info.x509_data.issuer_serial,:serial_number) do
                    Logger.debug("step4")
                    # check all the options
                    matching=Enum.all?(a.options, fn(o) -> Map.has_key?(o,:v_serial_num) and Map.has_key?(o,:deviceid) and Map.has_key?(o,:option_ident) and Map.has_key?(o,:option_desc) and Map.has_key?(o,:start_date) and Map.has_key?(o,:duration) and Map.has_key?(o,:duration_units) and Map.has_key?(o,:mode) and Map.has_key?(o,:sha1_digest) and Map.has_key?(o.deviceid,:manufacturer) and Map.has_key?(o.deviceid,:oui) and Map.has_key?(o.deviceid,:product_class) and Map.has_key?(o.deviceid,:serial_number) end)
                    matching
                  else
                    false
                  end
                else
                  false
                end
              else
                false
              end
            else
              false
            end
          end)
        else
          false
        end
      "GetOptions" ->
        # args is just a string with the option name
        String.valid?(args)
      "Upload" ->
        # args must at least contain commandkey, url and filetype
        is_map(args) and Map.has_key?(args,:commandkey) and Map.has_key?(args,:url) and Map.has_key?(args,:filetype)
      "FactoryReset" ->
        true # takes no params, always true
      "GetAllQueuedTransfers" ->
        true # takes no params, always true
      "ScheduleDownload" ->
        if is_map(args) and Map.has_key?(args,:url) and Map.has_key?(args,:filesize) and Map.has_key?(args,:filetype) and Map.has_key?(args,:timewindowlist) and is_list(args.timewindowlist) and length(args.timewindowlist)>0 do
          # Check that all elements of the timelist list conform
          Enum.all?(args.timewindowlist, fn(tw) ->
            is_map(tw) and Map.has_key?(tw,:window_start) and Map.has_key?(tw,:window_end) and Map.has_key?(tw,:window_mode) and Map.has_key?(tw,:max_retries)
          end)
        else
          false
        end
      "CancelTransfer" ->
        # args is just a string with the option name
        String.valid?(args)
      "ChangeDUState" ->
        if is_map(args) and Map.has_key?(args,:commandkey) and Map.has_key?(args,:operations) and is_list(args.operations) and length(args.operations)>0 do
          # Check that all elements of the operations list conform
          Enum.all?(args.operations, fn(o) ->
            if is_map(o) do
              case o do
                %CWMP.Protocol.Messages.InstallOpStruct{} ->
                  Map.has_key?(o,:url) and Map.has_key?(o,:uuid) and Map.has_key?(o,:username) and Map.has_key?(o,:password) and Map.has_key?(o,:execution_env_ref)
                %CWMP.Protocol.Messages.UpdateOpStruct{} ->
                  Map.has_key?(o,:url) and Map.has_key?(o,:uuid) and Map.has_key?(o,:username) and Map.has_key?(o,:password) and Map.has_key?(o,:version)
                %CWMP.Protocol.Messages.UninstallOpStruct{} ->
                  Map.has_key?(o,:url) and Map.has_key?(o,:uuid) and Map.has_key?(o,:execution_env_ref)
              end
            else
              false
            end
          end)
        else
          false
        end

      _ ->
        false
    end
  end

  defp generateID do
    Base.encode16(:erlang.md5(:crypto.strong_rand_bytes(32)), case: :lower)
  end


end
