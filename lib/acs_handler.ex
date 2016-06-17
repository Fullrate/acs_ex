defmodule ACS.ACSHandler do
  @moduledoc """
  CWMP southbound interface handler plug.

  Matches requests to the root as CWMP requests and forwards them to
  ACS.Handlers.ACS.
  """
  use Plug.Router
  use Plug.ErrorHandler
  require Logger

  plug ACS.RealIPSetter
  plug :match
  plug :dispatch

  defp handle_errors(conn, %{kind: kind, reason: reason, stack: stack}) do
    conn = ACS.RealIPSetter.call(conn, nil)
    entry = %{
      "ip"           => "#{:inet_parse.ntoa(conn.remote_ip)}",
      "ts"           => Timex.DateTime.now(:local) |> Timex.format!("{ISO}"),
      "host"         => conn.host,
      "msg"          => "ERROR: Unhandled exception occured",
      "trace"        => %{
        "kind" => inspect(kind),
        "reason" => inspect(reason),
        "stack" => inspect(stack),
      }
    }
    :ok = Logger.info(Poison.encode!(entry))
    send_resp(conn, conn.status, "Error handling request")
  end

  post _ do
    alias ACS.Handlers.ACS
    ACS.call(conn, ACS.init([]))
  end
end

