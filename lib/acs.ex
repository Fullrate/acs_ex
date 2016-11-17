defmodule ACS do
  @moduledoc """
  Request router for CPE->ACS

  """
  use Prometheus.Metric
  use Supervisor

  def start_link(session_handler, port, ip, opts \\ []) do
    Supervisor.start_link(__MODULE__, {port, ip, session_handler, opts})
  end

  def init({port, ip, session_handler, _opts}) do
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, ACS.ACSHandler, [session_handler], [port: port, ip: ip]),
      supervisor(ACS.Session.Supervisor, [session_handler])
    ]

    setup_prometheus()
    opts = [strategy: :one_for_one, name: ACS.Supervisor]
    supervise(children, opts)
  end

  defp setup_prometheus() do
    Counter.declare([name: :acs_ex_dead_session,
                    labels: [:product_class, :serial],
                    help: "Number of times a session has been stopped due to timeout in the acs-cpe sequence"])
    Gauge.declare([name: :acs_ex_nof_sessions,
                    labels: [:product_class, :serial],
                    help: "Number of ongoing sessions"])
  end
end
