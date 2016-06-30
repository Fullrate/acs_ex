defmodule ACS.Session.Script.Vendor.Helpers do
  require Logger

  @doc """

  args will be a list of names for the actual cwmp request.

  """
  def getParameterValues( session, args ) do
    Logger.debug("getParameterValues(#{inspect(args)})")
    session_call(session, %{method: "GetParameterValues", args: args, source: "script"})
  end

  # do the gen_server call
  defp session_call(session, command) do
    GenServer.call(session, {:script_command, [command]})
  end
end
