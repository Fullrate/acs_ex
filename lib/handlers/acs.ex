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
  use Plug.ErrorHandler

  plug(Plug.Parsers, parsers: [ACS.CWMP.Parser])
  plug(:dispatch)

  def dispatch(conn, _params) do
    cookies = fetch_cookies(conn).req_cookies

    session_id =
      cond do
        Map.has_key?(cookies, "session") ->
          Logger.debug("session cookie in the request, must be decoded into did")
          session_id = cookies["session"]
          # verify the session. Do we have a session with this ID, and does the did therein
          # match the IP of this request?
          cond do
            ACS.Session.verify_session(session_id, to_string(:inet_parse.ntoa(conn.remote_ip))) ->
              session_id

            true ->
              Logger.debug("session does not verify - sending Bad Request")
              ""
          end

        # verify_Session
        true ->
          Logger.debug("no cookie set in the request - should be an Inform then")

          case conn.body_params do
            %{cwmp_version: _cwmp_ver, entries: entries, header: _header} ->
              # Something that was parseable by cwmp_ex.
              case hd(
                     Enum.map(entries, fn entry ->
                       if(Map.has_key?(entry, :device_id), do: entry.device_id)
                     end)
                   ) do
                nil ->
                  Logger.debug("Cant find device_id in request nor cookie, bogus!")
                  ""

                didstruct ->
                  Logger.debug("device_id in the body - must be Inform, start session")
                  session_id = UUID.uuid4(:hex)

                  extended_deviceid =
                    Map.merge(Map.from_struct(didstruct), %{
                      ip: to_string(:inet_parse.ntoa(conn.remote_ip))
                    })

                  ACS.Session.Supervisor.start_session(
                    session_id,
                    extended_deviceid,
                    conn.body_params
                  )

                  session_id
              end

            # has device_id
            _ ->
              # unparseable body and no cookie, bogus
              Logger.debug("Cant find cwmp output in request nor cookie, bogus!")
              ""
          end

          # conn.body_params
      end

    # fetch_cookies

    {code, resp, session_id} =
      case session_id do
        "" ->
          {400, "Bad request", ""}

        {:reject, reason} ->
          Logger.error("Request rejected: #{inspect(reason)}")
          {404, "Not found", ""}

        _ ->
          {c, r} = ACS.Session.process_message(session_id, conn.body_params)
          {c, r, session_id}
      end

    if resp == "", do: ACS.Session.Supervisor.end_session(session_id)

    conn
    |> put_resp_content_type("text/xml")
    |> put_resp_cookie("session", session_id)
    |> send_resp(code, resp)
  end

  @doc """
  When our cwmp parser thows, we end up here. So when some CPE sends bogus
  xml, or half a record or whatever else they might do, this is where we capture
  that parser error from CWMP.Parser.
  """
  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    error =
      case reason do
        %Plug.Parsers.ParseError{
          exception: %CWMP.Protocol.Parser.ParseError{message: err_message}
        } ->
          "CWMP.Parser error: #{err_message}"

        %Plug.Parsers.ParseError{exception: _some_other_exception} ->
          "Plug.Parsers.ParseError raised"

        _ ->
          "Exception raised by Plug.Parsers"
      end

    Logger.error("Plug error: #{error}")
    send_resp(conn, conn.status, error)
  end
end
