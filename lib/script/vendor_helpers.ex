defmodule ACS.Session.Script.Vendor.Helpers do
  require Logger

  @doc """

  args must be a list of maps with "name", "type", "value"

  """
  def setParameterValues(session, args) do
    session_call(session, %{method: "SetParameterValues", args: args, source: "script"})
  end

  @doc """

  args will be a list of names for the actual cwmp request.

  """
  def getParameterValues(session, args) do
    session_call(session, %{method: "GetParameterValues", args: args, source: "script"})
  end

  @doc """

  args will be a maps with keys "parameter_path" and "next_level"

  """
  def getParameterNames(session, args) do
    session_call(session, %{method: "GetParameterNames", args: args, source: "script"})
  end

  @doc """

  args will be a list of maps each with keys "name", "notification_change", "notification", "accesslist_change"
  and "accesslist".

  """
  def setParameterAttributes(session, args) do
    session_call(session, %{method: "SetParameterAttributes", args: args, source: "script"})
  end

  @doc """

  args will be a list of string with paramter names for which you want to retrieve attributes.

  Return value will be a CWMP.Protocol.Messages.GetParameterAttributesResponse struct

  """
  def getParameterAttributes(session, args) do
    session_call(session, %{method: "GetParameterAttributes", args: args, source: "script"})
  end

  @doc """

  args must be a map with keys: "object_name" where the object name ends with .

  """
  def addObject(session, args) do
    session_call(session, %{method: "AddObject", args: args, source: "script"})
  end

  @doc """

  args must be a map with keys: "object_name" where the object name ends with .

  An optional parameter_key can be given

  Returns a CWMP.Protocol.Messages.AddObjectResponse

  """
  def deleteObject(session, args) do
    session_call(session, %{method: "DeleteObject", args: args, source: "script"})
  end

  @doc """

  call the session server with the script_commmand: reboot

  """
  def reboot(session) do
    session_call(session, %{method: "Reboot", args: [], source: "script"})
  end

  @doc """

  Sends a Download request info the session.

  args is a map containing the keys needed to generate at CWMP.Protocol.Messages.Download
  structure. i.e. "url", "filetype", "filesize" at least.

  """
  def download(session, args) do
    session_call(session, %{method: "Download", args: args, source: "script"})
  end

  @doc """

  Sends a GetQueuedTransfers request info the session.

  """
  def getQueuedTransfers(session) do
    session_call(session, %{method: "GetQueuedTransfers", args: nil, source: "script"})
  end

  @doc """

  Sends a ScheduleInform request info the session.

  """
  def scheduleInform(session, args) do
    session_call(session, %{method: "ScheduleInform", args: args, source: "script"})
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
