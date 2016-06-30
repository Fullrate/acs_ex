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
    GenServer.call(via_tuple(device_id), {:process_message, [device_id,message]})
  end

  @doc """

    Script message. This means the a scripting process wants a response to a request
    we just put the request in the plug queue and answer no_reply here.

  """
  def script_command(device_id, command) do
    # put it into the script_element
    GenServer.call(via_tuple(device_id), {:script_command, [command]})
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
    # Queue the response in the plug_queue, so that it can be popped with next response
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
        {:ok,%{device_id: device_id, script_element: nil, plug_element: nil, sspid: sspid, cwmp_version: message.cwmp_version}}
      _ -> {:stop, "Could not take over session"}
    end
  end

  @doc """

  Used for :trap_exit

  1. signal with reply/2 that this is over
  2. kill me

  """
  def handle_info({:EXIT, _pid, :normal}, state) do
    ## Session Script is done.
    case state.plug_element do
      nil -> Logger.debug( "Session script exited, and we have no waiting plug..." )
      %{message: _msg, from: from, state: :waiting} -> GenServer.reply(from, {200, ""})
      m -> IO.inspect(m)
      # Kill myself?
    end
    {:noreply,%{state | plug_element: nil, script_element: nil, sspid: nil}}
  end

  def handle_info(message, state) do
    IO.puts("Default handle_info(#{inspect message}, #{inspect state})")
  end

  def handle_call({:script_command, [command]}, from, state) do
    Logger.debug("handle_call(:script_command, [#{inspect(command)})")

    # If we have a waiting plug, we send at once!
    case state.plug_element do
      %{message: msg, from: from, state: :waiting} -> case validateArgs(command.method, command.args) do
                                                        true -> GenServer.reply(from, {200, gen_request(command.method, command.args, "script", msg.cwmp_version)})
                                                        false -> GenServer.reply(from, {200, ""})
                                                      end
                                                      {:noreply, %{state | plug_element: nil, script_element: %{command: command, from: from, state: :sent}}}

      _ -> Logger.debug( "No known plug_element, meaning no plug is waiting, so store script command in state" )
           # Just put the command in the script queue, we wont affect the plug queue until the
           # session reaches the "what now?" stage (empty request from device)
           {:noreply, %{state | script_element: %{command: command, from: from, state: :unhandled}}}
    end
  end

  def handle_call({:process_message, [device_id,message]}, from, state) do
    Logger.debug("handle_call(:process_message, #{inspect(device_id)}, #{inspect(message)})")

    # If this message is an Inform, it can be ignored, because the response to that
    # has already been queue in the plug_queue by init.

    # If this message is empty, it means that the session is about to end, unless
    # we have something more to send.

    # Anything else means that the front element in the script_element must be responsible for
    # this thing arriving, and the script is currently awaiting this reply, so we must :reply
    # now.
    {plug,script} = case length(Map.keys(message)) do
      0 -> # Empty message here. This means examine the script_element to see if there are
           # any new scripted message to push into the plug queue. If nothing can be found,
           # push "" into the plug_queue - ending the session. The Plug should kill it...
           Logger.debug("Empty message discovered: script_element: #{inspect(state.script_element)}")
           case state.script_element do
              nil -> # nothing in the script thing, we can end the session... if the session script process has exited.
                     case state.sspid do
                       nil -> {{200,""},nil} # we can stop...
                       pid -> # Here we have to wait for the Session Script to end before we can stop the session.
                              ## so we have to anwer {:noreply to the plug.. and hope for a reply later...}
                              {:noreply,nil}
                     end
              %{command: command, from: from, state: :unhandled} -> # And unhandled message from script?
                     # Transform the command to a plug_queue thing, and mark it :sent
                     case validateArgs(command.method, command.args) do
                       true -> {{200,gen_request(command.method, command.args, "script", state.cwmp_version)},
                                %{command: command, from: from, state: :sent}}
                       false -> Logger.debug("Cant validate args for command: #{inspect(command)}")
                                {:wait,nil}
                     end
              _ -> Logger.debug("Cant indentify script_element, clearing and discontinuing session: #{inspect(state.script_element)}")
                   {{200,""},nil}
           end

      3 -> Logger.debug("CWMP message discovered: script_element: #{inspect(state.script_element)}")
           # This could be a response that has to go to script land. In fact if the script_element
           # is empty this is weird and should be ignored and logged.

           # Could be that message is an Inform, in which case we just generate an InformResponse and dont stack anything in the plug element.
           case has_inform?(message.entries) do
             true -> Logger.debug("Session server saw inform, generating response")
                     {{200,CWMP.Protocol.Generator.generate!(
                                %CWMP.Protocol.Messages.Header{id: message.header.id},
                                %CWMP.Protocol.Messages.InformResponse{max_envelopes: 1}, message.cwmp_version)},state.script_element}
             false -> case state.script_element do
                        nil -> Logger.debug("Incomming non-inform message with no script element... what? - ignore that......or queue it somewhere in state if someone wants it")
                               {{200,""}, nil}
                        %{command: _command, from: from, state: :sent} -> Logger.debug("Incomming message is meant for script")
                               GenServer.reply(from, message)
                               # We have nothing to reply with here, so we must stuff this in OutstandingPlug and
                               # wait for someting from the Script, either next message or :EXIT
                               # we have to answer :noreply here, and
                               {:noreply, nil}
                      end
           end

      _ -> Logger.debug("Unknown message discovered - ignored")
           {state.plug_queue, state.script_element}
    end

    case plug do
      :noreply -> {:noreply, %{state | plug_element: %{message: message, from: from, state: :waiting}}}
      _ -> {:reply, plug, %{state | script_element: script}}
    end
  end

  def handle_call(request,from,state) do
    super(request,from,state)
  end

  defp via_tuple(device_id) do
    {:via, :gproc, {:n, :l, {:device_id, device_id}}}
  end

  # PRIVATE METHODS


  # interpret queue data, transform to appropriate CWMP.Protocol.Messages. struct and
  # ask CWMP.Protocol to generate
  defp gen_request(method,args,_source,cwmp_version) do
    Logger.debug("gen_request: #{method}")
    case validateArgs(method,args) do
      true -> case method do
        "GetParameterValues" -> params=for a <- args, do: %CWMP.Protocol.Messages.GetParameterValuesStruct{name: a["name"], type: a["type"]}
                                CWMP.Protocol.Generator.generate!(%CWMP.Protocol.Messages.Header{id: generateID}, %CWMP.Protocol.Messages.GetParameterValues{parameters: params}, cwmp_version)
        "SetParameterValues" -> params=for a <- args, do: %CWMP.Protocol.Messages.ParameterValueStruct{name: a["name"], type: a["type"], value: a["value"]}
                                CWMP.Protocol.Generator.generate!(%CWMP.Protocol.Messages.Header{id: generateID}, %CWMP.Protocol.Messages.SetParameterValues{parameters: params}, cwmp_version)
        "Reboot" -> CWMP.Protocol.Generator.generate!(%CWMP.Protocol.Messages.Header{id: generateID}, %CWMP.Protocol.Messages.Reboot{})
        "Download" -> argslist=for k <- Map.keys(args), do: {String.to_atom(k),Map.get(args,k)}
                      CWMP.Protocol.Generator.generate!(
                         %CWMP.Protocol.Messages.Header{id: generateID},
                         struct(CWMP.Protocol.Messages.Download, argslist))
        _ -> Logger.error("Cant match request method: #{method}")
        ""
      end
      false -> Logger.error("arguments for request #{method} do not validate")
               ""
    end
  end

  defp validateArgs(method,args) do
    case method do
      "GetParameterValues" -> # args must be map with name and type key in all elements
        case args do
          l when is_list(l) and length(l) > 0 -> Enum.all?(args, fn(a) -> is_map(a) and Map.has_key?(a,:name) and Map.has_key?(a,:type) end)
          _ -> false
        end
      "SetParameterValues" -> # args must be list of maps with name,type and value keys
        case args do
          l when is_list(l) and length(l) > 0 -> Enum.all?(args, fn(a) -> Map.has_key?(a,"name") && Map.has_key?(a,"type") && Map.has_key?(a,"value") end)
          _ -> false
        end
      "Reboot" -> true
      "Download" -> true
    end
  end

  defp generateID do
    Base.encode16(:erlang.md5(:crypto.strong_rand_bytes(32)), case: :lower)
  end

  def has_inform?([]), do: false
  def has_inform?([%CWMP.Protocol.Messages.Inform{} | _]), do: true
  def has_inform?([_ | es]), do: has_inform?(es)

end
