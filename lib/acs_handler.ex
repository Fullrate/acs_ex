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

  @doc """

  override af Plug.Router's call

  """
  def call(conn, [session_handler] = opts) do
    super(Plug.Conn.put_private(conn, :session_handler, session_handler), opts)
  end

  defp handle_errors(conn, %{kind: kind, reason: reason, stack: stack}) do
    conn = ACS.RealIPSetter.call(conn, nil)
    entry = %{
      "ip"           => "#{:inet_parse.ntoa(conn.remote_ip)}",
      "ts"           => DateTime.utc_now() |> DateTime.to_iso8601,
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

  def init(opts) do
    opts
  end
end

