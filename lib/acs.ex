defmodule ACS do
  @moduledoc """
  Request router for CPE->ACS

  """
  use Supervisor

  def start_link(session_handler, port, ip, opts \\ []) do
    Supervisor.start_link(__MODULE__, {port, ip, session_handler, opts})
  end

  def init({port, ip, session_handler, _opts}) do
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, ACS.ACSHandler, [session_handler], [port: port, ip: ip]),
      supervisor(ACS.Session.Supervisor, [session_handler])
    ]

    opts = [strategy: :one_for_one, name: ACS.Supervisor]
    supervise(children, opts)
  end

end
