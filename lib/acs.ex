defmodule ACS do
  @moduledoc """
  Request router for CPE->ACS

  """
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      Plug.Adapters.Cowboy.child_spec(:http, ACS.ACSHandler, [], [port: Application.fetch_env!(:acs_ex, :acs_port)]),
      supervisor(ACS.RedixPool, []),
    ]

    opts = [strategy: :one_for_one, name: ACS.Supervisor]
    Supervisor.start_link(children, opts)
    ACS.Session.Supervisor.start_link
  end
end
