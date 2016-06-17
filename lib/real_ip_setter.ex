defmodule ACS.RealIPSetter do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _params) do
    ret = with [realip | _] <- get_req_header(conn, "x-forwarded-for"),
               {:ok, addr} <- :inet.parse_address('#{realip}'),
               do: {:ok, addr}
    case ret do
      {:ok, addr} -> %Plug.Conn{conn | remote_ip: addr}
      _ -> conn
    end
  end
end
