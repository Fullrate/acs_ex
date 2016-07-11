defmodule ACS.Session do
  use GenServer
  require Logger

  @encryptor Cryptex.MessageEncryptor.new(
    Cryptex.KeyGenerator.generate(Application.fetch_env!(:acs_ex,:crypt_keybase), Application.fetch_env!(:acs_ex,:crypt_cookie_salt)),
    Cryptex.KeyGenerator.generate(Application.fetch_env!(:acs_ex,:crypt_keybase), Application.fetch_env!(:acs_ex,:crypt_signed_cookie_salt)))

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
  def start_link(device_id,message,fun \\ nil) do
    GenServer.start_link(__MODULE__, [device_id,message,fun])
  end

  # API

  @doc """

    when stuff is sent into this session, like CWMP messages
    or other stuff.

  """
  def process_message(device_id, message) do
    try do
      timeout=case Application.fetch_env(:acs_ex, :session_timeout) do
        {:ok, to} -> to
        :error -> 30000
      end
      GenServer.call(via_tuple(device_id), {:process_message, [device_id,message]}, timeout)
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

    Script message. This means the a scripting process wants a response to a request
    we just put the request in the plug queue and answer no_reply here.

  """
  def script_command(device_id, command) do
    # put it into the script_element
    Logger.debug("API script_command called...#{inspect device_id}, #{inspect command}")
    try do
      timeout=case Application.fetch_env(:acs_ex, :script_timeout) do
        {:ok, to} -> to
        :error -> 2000
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

  defp takeover_session(device_id, tries \\ 5)

  defp takeover_session(_device_id, 0), do: {:error, "Could not take over session"}
  defp takeover_session(device_id, tries) do
    case :gproc.reg_or_locate({:n, :l, {:device_id, device_id}}) do
      {other, _} when other == self() ->
        :ok
      {other, _} ->
        ref = Process.monitor(other)
        Process.exit(other, :kill) # TODO: Maybe send a poison pill?
        receive do
          {:DOWN, _ref, :process, _other, _} -> takeover_session(device_id, tries-1)
        after
          1000 ->
            Process.demonitor(ref, :flush)
            takeover_session(device_id, tries-1)
        end
    end
  end

  # SERVER

  def init([device_id,message,fun]) do
    Logger.debug("Session gen_server init(#{inspect(device_id)}, #{inspect(message)})")

    # This should only be called when the Plug gets an Inform, it this up
    # to me to check, or the caller? I will assume caller.

    # This conn.body_params must be a parsed Inform, if not - ignore
    # Queue the response in the plug_element, so that it can be popped with next response
    # InformResponse into the plug queue

    gspid=self
    sspid=case fun do
      nil -> spawn_link(ACS.Session.Script.Vendor, :start, [gspid, device_id, hd(message.entries)]) # TODO: Should be "first inform encountered", not just hd
      f when is_function(f) -> spawn_link(fn() -> fun.(gspid, device_id, hd(message.entries)) end)
      _ -> spawn_link(fun, :start, [gspid, device_id, hd(message.entries)]) # assume some other module
    end

    # Start session script process, save pid to state
    case takeover_session(device_id) do
      :ok ->
        Process.flag(:trap_exit, true)
        {:ok,%{device_id: device_id, script_element: nil, plug_element: nil, unmatched_incomming_list: [], sspid: sspid, cwmp_version: message.cwmp_version}}
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
      nil -> Logger.debug( "Session script exited, and we have no waiting plug..." )
      pe -> # Waiting plug, we have to tell it to stop by sending {200,""}
           Logger.debug("Waiting plug when SS ends, just tell it to stop, which in turn will kill me (the session)")
           GenServer.reply( pe.from, {200, ""} )
    end
    {:noreply,%{state | plug_element: nil, script_element: nil, sspid: nil}}
  end

  def handle_info(message, state) do
    IO.puts("Default handle_info(#{inspect message}, #{inspect state})")
  end

  def handle_call({:script_command, [command]}, from, state) do
    Logger.debug("handle_call(:script_command, [#{inspect(command)})")

    case state.plug_element do
      %{message: _msg, from: plug_from, state: :waiting} ->
        # A plug is waiting when a scripting function has not ended, and the plug is ready for more requests
        # meaning it received "" from a CPE indicating that the CPE has nothing more. We keep waiting
        # because the scripting system is supposed to introduce new reqeusts, that is its purpose, and
        # as long as it is not dead, we must expect more.
        Logger.debug("Session Script discovered a waiting plug. Sending scripted command at once!")
        case validateArgs(command.method, command.args) do
          true -> {id,req} = gen_request(command.method, command.args, "script", state.cwmp_version)
                  GenServer.reply(plug_from, {200, req})
                  {:noreply, %{state | plug_element: nil, script_element: %{command: command, from: from, state: :sent, id: id}}}
          false -> # some error should be returned to "from" who is the SS
                   {:reply, {:error, "Message is unparsable"}, %{state | script_element: nil}}
        end

      _ -> Logger.debug( "No known plug_element, meaning no plug is waiting, so store script command in state" )
           # Just put the command in the script element, we wont affect the plug queue until the
           # session reaches the "what now?" stage (empty request from device)
           {:noreply, %{state | script_element: %{command: command, from: from, state: :unhandled}}}
    end
  end

  @doc """

  Returns the list of messages received from a CPE during a session who are not the
  result of a script requesting it. ie. TransferComplete aso

  """
  def handle_call({:unscripted, []}, _from, state) do
    {:reply, state.unmatched_incomming_list, state}
  end

  @doc """

  Processes a message from the plug. "message" is the CWMP.Protocol version of
  the parsed request sent into the plug.

  """
  def handle_call({:process_message, [device_id,message]}, from, state) do
    Logger.debug("handle_call(:process_message, #{inspect(device_id)}, #{inspect(message)})")

    # If this message is an Inform, it can be ignored, because the response to that
    # has already been queue in the plug_element by init.
    # If this message is empty, it means that the session is about to end, unless
    # we have something more to send.

    # Anything else means that the front element in the script_element must be responsible for
    # this thing arriving, and the script is currently awaiting this reply, so we must :reply
    # now.
    {plug,script,unmatched,sspid} = case length(Map.keys(message)) do
      0 -> # Empty message here. This means examine the script_element to see if there are
           # any new scripted message to push into the plug queue. If nothing can be found,
           # push "" into the plug_element - ending the session. The Plug should kill it...
           Logger.debug("Empty message discovered: sspid: #{inspect state.sspid}, script_element: #{inspect(state.script_element)}")
           case state.script_element do
              nil -> # nothing in the script thing, we can end the session... if the session script process has exited.
                     Logger.debug("No script_element")
                     case state.sspid do
                       nil -> # no session script
                              Logger.debug("No script pid")
                              {{200,""},nil,[],state.sspid} # we can stop...
                       sspid -> # Session script is going, but no element?? Maybee this is before it could queue
                                # or maybee its in some long operation
                              if Process.alive?(sspid) do
                                Logger.debug("Script system IS alive ....")
                                {:noreply,nil,[],sspid}
                              else
                                Logger.debug("Script system is not actually alive, it only seems so. Missed an :exit?")
                                {{200,""},nil,[],nil}
                              end
                     end
              %{command: command, from: script_from, state: :unhandled} -> # And unhandled message from script?
                     Logger.debug("There is a script element")
                     # Transform the command to a plug_element thing, and mark it :sent
                     case validateArgs(command.method, command.args) do
                       true -> {id,req} = gen_request(command.method, command.args, "script", state.cwmp_version)
                               {{200,req}, %{command: command, from: script_from, state: :sent, id: id}, [], state.sspid}
                       false -> Logger.debug("Cant validate args for command: #{inspect(command)}")
                                # must send reply to SS with error, even though this should never happen,
                                # then we must continue to wait in the plug
                                GenServer.reply(script_from, {:error, "Command does not validate"})
                                {:noreply,nil,[],state.sspid}
                     end
              _ -> Logger.debug("Cant indentify script_element, clearing and discontinuing session: #{inspect(state.script_element)}")
                   {{200,""},nil,[],nil}
           end

      3 -> Logger.debug("CWMP message discovered: script_element: #{inspect(state.script_element)}")
           # This could be a response that has to go to script land. In fact if the script_element
           # is empty this is weird and should be ignored and logged.

           # Could be that message is an Inform, in which case we just generate an InformResponse and dont stack anything in the plug element.
           case has_inform?(message.entries) do
             true ->
               Logger.debug("Session server saw inform, generating response")
               {{200,CWMP.Protocol.Generator.generate!(
                 %CWMP.Protocol.Messages.Header{id: message.header.id},
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
                     {:noreply, nil, [], state.sspid}
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
                 end
           end

      _ -> Logger.debug("Unknown message discovered - ignored")
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

  defp via_tuple(device_id) do
    {:via, :gproc, {:n, :l, {:device_id, device_id}}}
  end

  # PRIVATE METHODS

  defp construct_reply( message ) do
    entry = hd(message.entries)
    case message_type(entry) do
      {:cpe,_messagetype} ->
        # ...Response and that type
        # This means "Fault" - because this response is off track
        {{200,CWMP.Protocol.Generator.generate!(
           %CWMP.Protocol.Messages.Header{id: message.header.id},
           %CWMP.Protocol.Messages.Fault{faultcode: "Server", faultstring: "CWMP fault", detail:
             %CWMP.Protocol.Messages.FaultStruct{code: "8003", string: "Invalid arguments"}})},[]}
      {:acs,CWMP.Protocol.Messages.GetRPCMethods} ->
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: message.header.id},
          %CWMP.Protocol.Messages.GetRPCMethodsResponse{methods: ["GetRPCMethods","Inform","TransferComplete","AutonomousTransferComplete","Kicked","RequestDownload","DUStateChangeComplete","AutonomousDUStateChangeComplete"]})},[message]}
      {:acs,CWMP.Protocol.Messages.TransferComplete} ->
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: message.header.id},
          %CWMP.Protocol.Messages.TransferCompleteResponse{})},[message]}
      {:acs,CWMP.Protocol.Messages.AutonomousTransferComplete} ->
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: message.header.id},
          %CWMP.Protocol.Messages.AutonomousTransferCompleteResponse{})},[message]}
      {:acs,CWMP.Protocol.Messages.Kicked} ->
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: message.header.id},
          %CWMP.Protocol.Messages.KickedResponse{next_url: entry.next})},[message]}
      {:acs,CWMP.Protocol.Messages.RequestDownload} ->
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: message.header.id},
          %CWMP.Protocol.Messages.RequestDownloadResponse{})},[message]}
      {:acs,CWMP.Protocol.Messages.DUStateChangeComplete} ->
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: message.header.id},
          %CWMP.Protocol.Messages.DUStateChangeCompleteResponse{})},[message]}
      {:acs,CWMP.Protocol.Messages.AutonomousDUStateChangeComplete} ->
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: message.header.id},
          %CWMP.Protocol.Messages.AutonomousDUStateChangeCompleteResponse{})},[message]}

      _ ->
        # unknown message type, what to do? - Fault back?
        {{200,CWMP.Protocol.Generator.generate!(
          %CWMP.Protocol.Messages.Header{id: message.header.id},
            %CWMP.Protocol.Messages.Fault{faultcode: "Server", faultstring: "CWMP fault", detail:
            %CWMP.Protocol.Messages.FaultStruct{code: "8000", string: "Method not supported"}})},[]}
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

      _ -> {:unknown,entry.__struct__}
    end
  end

  # interpret queue data, transform to appropriate CWMP.Protocol.Messages. struct and
  # ask CWMP.Protocol to generate
  defp gen_request(method,args,_source,cwmp_version) do
    Logger.debug("gen_request: #{method}")
    case validateArgs(method,args) do
      true ->
        id=generateID
        header=%CWMP.Protocol.Messages.Header{id: id}
        message=case method do
          "GetRPCMethods" ->
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.GetRPCMethods{})
          "SetParameterValues" ->
            params=for a <- args, do: %CWMP.Protocol.Messages.ParameterValueStruct{name: a.name, type: a.type, value: a.value}
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.SetParameterValues{parameters: params}, cwmp_version)
          "GetParameterValues" ->
            params=for a <- args, do: %CWMP.Protocol.Messages.GetParameterValuesStruct{name: a, type: "string"}
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.GetParameterValues{parameters: params}, cwmp_version)
          "GetParameterNames" ->
            params=%CWMP.Protocol.Messages.GetParameterNames{parameter_path: args.parameter_path, next_level: args.next_level}
            CWMP.Protocol.Generator.generate!(header, params)
          "SetParameterAttributes" ->
            params=for a <- args, do: %CWMP.Protocol.Messages.SetParameterAttributesStruct{
              name: a.name,
              notification_change: a.notification_change,
              notification: a.notification,
              accesslist_change: a.accesslist_change,
              accesslist: a.accesslist
            }
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.SetParameterAttributes{parameters: params}, cwmp_version)
          "Reboot" ->
            CWMP.Protocol.Generator.generate!(header, %CWMP.Protocol.Messages.Reboot{})
          "Download" ->
            Logger.debug("Download args: #{inspect args}")
            CWMP.Protocol.Generator.generate!(header, struct(CWMP.Protocol.Messages.Download, args))
          _ ->
            Logger.error("Cant match request method: #{method}")
            ""
        end
        {id,message}
      false -> Logger.error("arguments for request #{method} do not validate")
               {0,""}
    end
  end

  defp validateArgs(method,args) do
    case method do
      "GetRPCMethods" -> true # No args for this one
      "SetParameterValues" -> # args must be list of maps with name,type and value keys
        case args do
          l when is_list(l) and length(l) > 0 -> Enum.all?(args, fn(a) -> Map.has_key?(a,:name) && Map.has_key?(a,:type) && Map.has_key?(a,:value) end)
          _ -> false
        end
      "GetParameterValues" -> # args must be map with name and type key in all elements
        case args do
          l when is_list(l) and length(l) > 0 -> Enum.all?(args, fn(a) -> String.valid?(a) end)
          _ -> false
        end
      "GetParameterNames" -> # args must be map with path and next_level keys
        Map.has_key?(args,:parameter_path) and Map.has_key?(args,:next_level)
      "SetParameterAttributes" -> # args must be map with path and next_level keys
        case args do
          l when is_list(l) and length(l) > 0 -> Enum.all?(args, fn(a) -> Map.has_key?(a,:name) and Map.has_key?(a,:notification_change) and Map.has_key?(a,:notification) and Map.has_key?(a,:accesslist_change) and Map.has_key?(a,:accesslist) and is_list(a.accesslist) end)
          _ -> false
        end
      "Reboot" -> true # takes no params, always true
      "Download" -> Map.has_key?(args,:url) and Map.has_key?(args,:filesize) and Map.has_key?(args,:filetype)
    end
  end

  defp generateID do
    Base.encode16(:erlang.md5(:crypto.strong_rand_bytes(32)), case: :lower)
  end

  def has_inform?([]), do: false
  def has_inform?([%CWMP.Protocol.Messages.Inform{} | _]), do: true
  def has_inform?([_ | es]), do: has_inform?(es)

end
