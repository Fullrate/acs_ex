defmodule ACS do
  @moduledoc """
  Request router for CPE->ACS

  """
  use Supervisor

  def start_link(session_handler, port, opts \\ []) do
    Supervisor.start_link(__MODULE__, {port, session_handler, opts})
  end

  def init({port, session_handler, _opts}) do

    children = [
      Plug.Adapters.Cowboy.child_spec(:http, ACS.ACSHandler, [session_handler], [port: port]),
      supervisor(ACS.Session.Supervisor, [session_handler])
    ]

    opts = [strategy: :one_for_one, name: ACS.Supervisor]
    supervise(children, opts)
  end

end
