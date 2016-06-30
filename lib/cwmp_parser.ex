defmodule ACS.CWMP.Parser do
  @moduledoc """
  This module implements a simple wrapper around the cwmp_ex CWMP library
  parser. The request body is assumed to be a SOAP envelope containing one or
  more CWMP requests/responses.
  """

  @behaviour Plug.Parsers
  import Plug.Conn
  require Logger

  @doc """
  Parses text/xml requests as CWMP requests/responses.

  The resulting CWMP requests and responses are returned so they can be set as
  the body_params field of the connection.
  """
  def parse(conn, type, subtype, headers, opts)

  def parse(conn, "text", "xml", _headers, _opts) do
    {:ok, body, conn} = read_body(conn, [])
    case body do
      "" -> {:ok, %{}, conn}
      _ -> case CWMP.Protocol.Parser.parse(body) do
             {:ok, parsed} -> {:ok, parsed, conn}
             {:error, err} -> raise Plug.Parsers.ParseError, exception: err
           end
    end
  end

  def parse(conn, _, _, _, _) do
    {:next, conn}
  end
end

