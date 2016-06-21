defmodule ACS.Handlers.ACS do
  @moduledoc """
  Handles CWMP requests coming in over the CWMP southbound interface.

  Requests are parsed as SOAP CWMP envelopes and then used for the basis
  of the current provisioning tree. There are several possible request types
  as defined in the TR-069 specification. These are all just handled by
  the custom logic module.

  Some are part of basic ACS functionality and are handled here.

  This is the main ACS server loop corresponding to the old acs3.pm
  """
  require Logger
  use Plug.Builder

  plug Plug.Parsers, parsers: [ACS.CWMP.Parser]
  plug :dispatch

  @encryptor Cryptex.MessageEncryptor.new(
    Cryptex.KeyGenerator.generate(Application.fetch_env!(:acs_ex,:crypt_keybase), Application.fetch_env!(:acs_ex,:crypt_cookie_salt)),
    Cryptex.KeyGenerator.generate(Application.fetch_env!(:acs_ex,:crypt_keybase), Application.fetch_env!(:acs_ex,:crypt_signed_cookie_salt)))

  def dispatch(conn, _params) do
    did=%{}

    Logger.debug("Received headers: #{inspect(conn.req_headers)}")
    Logger.debug("Received body: #{inspect(conn.body_params)}")

    # Handle cookies.
    c = fetch_cookies(conn)

    case c.req_cookies do
      %Plug.Conn.Unfetched{aspect: :cookies} -> Logger.debug("3. no cookies set")
      cook -> case Map.has_key?(cook,"session") do
        false -> ""
        true -> Logger.debug("session cookie in the request, decode into did #{inspect(cook["session"])}")
                case Cryptex.MessageEncryptor.decrypt_and_verify(@encryptor,cook["session"]) do
                  {:ok,json} -> case Poison.decode(json) do
                    {:ok,dec} -> did=dec
                                 Logger.debug("3a. Got #{inspect(did)} from cookie")
                  end
                end
      end
    end

    resp=""
    case conn.body_params do
      %{cwmp_version: cwmp_ver, entries: entries, header: header} ->
          case hd(Enum.map(entries,fn(entry) -> if(Map.has_key?(entry,:device_id), do: entry.device_id) end)) do
            nil -> Logger.debug( "Cant find device_id in request" )
            didstruct -> did = did |> Map.merge(Map.from_struct(didstruct)) |> Map.merge( %{cwmp_version: extract_cwmp_version(cwmp_ver)})
          end
          resp=Enum.map( entries, fn(e) -> Trigger.event(e,header,did) end ) |> Enum.join("\n\n")
      %{} ->
             # empty body could also mean bogus request, meaning request with no cookie, there for no did
             case  Map.has_key?(did,"serial_number") do
               true -> Logger.debug( "Empty body - dequeue request for cpe #{inspect(did)}" )
                       deq=ACS.Queue.dequeue(did["serial_number"])
                       Logger.debug("deq=#{inspect(deq)}")
                       resp=case deq do
                         {:ok,%{"dispatch" => dispatch, "source" => source, "args" => args}} -> gen_request(dispatch,args,source,did)
                         junk -> Logger.debug("cant match dequeued event: #{inspect(junk)}")
                                 ""
                       end
               false -> Logger.debug("Empty request with no cookie, bogus!")
             end
    end

    # end - generate and send responses, set cookie
    Logger.debug("Response headers: #{inspect(conn.resp_headers)}")
    Logger.debug("[#{inspect(did)}] Sending response [#{resp}]")
    conn
    |> put_resp_content_type("text/xml")
    |> put_resp_cookie("session",
              Cryptex.MessageEncryptor.encrypt_and_sign(@encryptor,Poison.encode(did)),
              [{:path, '/'}])
    |> send_resp(200,resp)
  end

  @doc """
  Extracts the InformRequest from a CWMP envelope. If there are multiple such
  requests, or none at all, returns an error.
  """
  def extract_inform(request) do
    informs = for %CWMP.Protocol.Messages.Inform{} = e <- request.entries, do: e
    case informs do
      [inform] -> {:ok, inform}
      [_ | _] -> {:error, "Multiple informs in request"}
      [] -> {:error, "No inform request found"}
    end
  end

  # interpret queue data, transform to appropriate CWMP.Protocol.Messages. struct and
  # ask CWMP.Protocol to generate
  defp gen_request(method,args,source,did) do
    Logger.debug("gen_request: #{method}")
    case validateArgs(method,args) do
      true -> case method do
        "GetParameterValues" -> params=for a <- args, do: %CWMP.Protocol.Messages.GetParameterValuesStruct{name: a["name"], type: a["type"]}
                                CWMP.Protocol.Generator.generate(%CWMP.Protocol.Messages.Header{id: generateID}, %CWMP.Protocol.Messages.GetParameterValues{parameters: params}, did["cwmp_version"])
        "SetParameterValues" -> params=for a <- args, do: %CWMP.Protocol.Messages.ParameterValueStruct{name: a["name"], type: a["type"], value: a["value"]}
                                CWMP.Protocol.Generator.generate(%CWMP.Protocol.Messages.Header{id: generateID}, %CWMP.Protocol.Messages.SetParameterValues{parameters: params}, did["cwmp_version"])
        _ -> Logger.error("Cant match request method: #{method}")
      end
      false -> Logger.error("arguments for request #{method} do not validate")
    end
  end

  defp validateArgs(method,args) do
    case method do
      "GetParameterValues" -> # args must be map with name and type key in all elements
        Enum.all?(args, fn(a) -> Map.has_key?(a,"name") && Map.has_key?(a,"type") end)
      "SetParameterValues" -> # args must be list of maps with name,type and value keys
        Enum.all?(args, fn(a) -> Map.has_key?(a,"name") && Map.has_key?(a,"type") && Map.has_key?(a,"value") end)
    end
  end

  defp extract_cwmp_version(versionuri) do
    case Regex.run(~r/.*dslforum-org:cwmp-(\d-\d)$/,versionuri) do
      [_,ver] -> ver
      _ -> "1-0"
    end
  end

  defp generateID do
    Base.encode16(:erlang.md5(:crypto.strong_rand_bytes(32)), case: :lower)
  end

end
