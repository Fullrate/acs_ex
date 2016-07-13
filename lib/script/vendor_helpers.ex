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

  Sends a SetVouchers request info the session.

  """
  def setVouchers(session, args) do
    session_call(session, %{method: "SetVouchers", args: args, source: "script"})
  end

  @doc """

  Sends a GetOptions request info the session.

  Args is the option name, just a string

  """
  def getOptions(session, args) do
    session_call(session, %{method: "GetOptions", args: args, source: "script"})
  end

  @doc """

  Sends an Upload request info the session.

  Args is a map containing at least commandkey, filetype and url out of the following
  possible keys, here listed with defaults:
            commandkey: "",
            filetype: nil,
            url: nil,
            username: "",
            password: "",
            delay_seconds: 0

  """
  def upload(session, args) do
    session_call(session, %{method: "Upload", args: args, source: "script"})
  end

  @doc """

  Sends a FactoryReset request info the session.

  """
  def factoryReset(session) do
    session_call(session, %{method: "FactoryReset", args: nil, source: "script"})
  end

  @doc """

  Sends an GetAllQueuedTransfers request info the session.

  """
  def getAllQueuedTransfers(session) do
    session_call(session, %{method: "GetAllQueuedTransfers", args: nil, source: "script"})
  end

  @doc """

  Sends a ScheduleDownload request info the session.

  args is a map containing the keys needed to generate at CWMP.Protocol.Messages.ScheduleDownload
  structure. i.e.
        commandkey (May be empty)
        filetype
        url
        username (Optional)
        password (Optional)
        filesize
        target_filename (Optional)
        timewindowlist [%{
          window_start
          window_end
          window_mode
          user_message (May be "")
          max_retries}]

  """
  def scheduleDownload(session, args) do
    session_call(session, %{method: "ScheduleDownload", args: args, source: "script"})
  end

  @doc """

  Sends a GetOptions request info the session.

  Args is a commandkey, just a string

  """
  def cancelTransfer(session, args) do
    session_call(session, %{method: "CancelTransfer", args: args, source: "script"})
  end

  @doc """

  Sends a ChangeDUState request info the session.

  args is a map containing the keys needed to generate at CWMP.Protocol.Messages.ChangeDUState
  structure. This means that the elements in the operations list need to be one (or more) of the
  struct types:
     %CWMP.Protocol.Messages.InstallOpStruct{url: url, uuid: uuid, username: user, password: pass, execution_env_ref: eer}
     %CWMP.Protocol.Messages.UpdateOpStruct{url: url, uuid: uuid, username: user, password: pass, version: ver}
     %CWMP.Protocol.Messages.UninstallOpStruct{url: url, uuid: uuid, execution_env_ref: eer}

  For example:
        commandkey (May be "")
        operations: [
          %CWMP.Protocol.Messages.InstallOpStruct{
            url
            uuid
            username (May be "")
            password (May be "")
            execution_env_ref
          }]

  """
  def changeDUState(session, args) do
    session_call(session, %{method: "ChangeDUState", args: args, source: "script"})
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
