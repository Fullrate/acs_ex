defmodule ACS.Session.Script.Vendor.Helpers do
  require Logger

  @doc """

  args will be a list of names for the actual cwmp request.

  """
  def getParameterValues(session, args) do
    session_call(session, %{method: "GetParameterValues", args: args, source: "script"})
  end

  @doc """

  args must be a list of maps with "name", "type", "value"

  """
  def setParameterValues(session, args) do
    session_call(session, %{method: "SetParameterValues", args: args, source: "script"})
  end

  @doc """

  call the session server with the script_commmand: reboot

  """
  def reboot(session) do
    session_call(session, %{method: "Reboot", args: [], source: "script"})
  end

  @doc """

  Get the current list of ACS messages, i.e. TransferComplete aso from the session.

  """
  def session_messages(session) do
    Logger.debug("Vendor.Helpers session_call :unscripted called")
    GenServer.call(session, {:unscripted, []})
  end

  # do the gen_server call
  defp session_call(session, command) do
    Logger.debug("Vendor.Helpers session_call :script_command called: command: #{command.method} with args: #{inspect(command.args)}")
    GenServer.call(session, {:script_command, [command]})
  end

end
