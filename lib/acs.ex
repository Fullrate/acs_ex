defmodule ACS do
  @moduledoc """
  Request router for CPE->ACS

  """
  use Prometheus.Metric
  use Supervisor

  def start_link(session_handler, port, ip, ip6, opts \\ []) do
    Supervisor.start_link(__MODULE__, {port, ip, ip6, session_handler, opts})
  end

  def init({port, ip, ip6, session_handler, _opts}) do
    children = ipv4_listeners(session_handler, ip, port)
    children = children ++ [
      supervisor(ACS.Session.Supervisor, [session_handler])
    ]

    children = children ++ if ( is_tuple( ip6 ) && length( Tuple.to_list(ip6) ) == 8 ) do
      # ipv6 listeners
      ipv6_listeners(session_handler, ip6, port)
    else
      []
    end

    setup_prometheus()
    opts = [strategy: :one_for_one, name: ACS.Supervisor]
   # supervise(children, opts)
   Supervisor.init(children, opts)
  end

  defp ipv6_listeners(session_handler, ip6, port) when is_integer(port) do
    cowboy_timeout=case Application.fetch_env(:acs_ex, :cowboy_timeout) do
      {:ok, to} -> to
      :error -> 60000
    end
    request_timeout=case Application.fetch_env(:acs_ex, :request_timeout) do
      {:ok, to} -> to
      :error -> 45000
    end
    #[Plug.Adapters.Cowboy.child_spec(:http, ACS.ACSHandler, [session_handler], [:inet6, port: port, ip: ip6, ipv6_v6only: true, timeout: 30000, ref: String.to_atom("ipv6_listener_#{port}")])]
    [{Plug.Cowboy, scheme: :http, plug: {ACS.ACSHandler, [session_handler]}, options: [:inet6, port: port, ip: ip6, ipv6_v6only: true, timeout: cowboy_timeout, protocol_options: [request_timeout: request_timeout], ref: String.to_atom("ipv6_listener_#{port}")]}]
  end

  defp ipv6_listeners(session_handler, ip6, [port]) when is_integer(port) do
     ipv6_listeners(session_handler, ip6, port)
  end

  defp ipv6_listeners(session_handler, ip6, [ port | rest ] ) do
    ipv6_listeners(session_handler, ip6, port) ++ ipv6_listeners(session_handler, ip6, rest)
  end

  defp ipv4_listeners(session_handler, ip, port) when is_integer(port) do
#    [ Plug.Adapters.Cowboy.child_spec(:http, ACS.ACSHandler, [session_handler], [port: port, ip: ip, timeout: 30000, ref: String.to_atom("ipv4_listener_#{port}")]) ]
    cowboy_timeout=case Application.fetch_env(:acs_ex, :cowboy_timeout) do
      {:ok, to} -> to
      :error -> 60000
    end
    request_timeout=case Application.fetch_env(:acs_ex, :request_timeout) do
      {:ok, to} -> to
      :error -> 45000
    end
    [{Plug.Cowboy, scheme: :http, plug: {ACS.ACSHandler, [session_handler]}, options: [port: port, ip: ip, timeout: cowboy_timeout, protocol_options: [request_timeout: request_timeout], ref: String.to_atom("ipv4_listener_#{port}")]}]
  end

  defp ipv4_listeners(session_handler, ip, [port] ) when is_integer(port) do
    ipv4_listeners(session_handler, ip, port)
  end

  defp ipv4_listeners(session_handler, ip, [ port | rest ] ) do
    ipv4_listeners(session_handler, ip, port) ++ ipv4_listeners(session_handler, ip, rest)
  end

  defp setup_prometheus() do
    Counter.declare([name: :acs_ex_dead_sessions,
                    labels: [:product_class],
                    help: "Number of times a session has been stopped due to timeout in the acs-cpe sequence"])
    Gauge.declare([name: :acs_ex_nof_sessions,
                    labels: [:product_class],
                    help: "Number of ongoing sessions"])
  end
end
