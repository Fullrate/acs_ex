defimpl Trigger, for: CWMP.Protocol.Messages.SetParameterValuesResponse do
  require Logger
  @doc """
    SetParameterValuesResponse comes in here. This is where you implement
    what is to happen in the arrival of this messages. Maybe advance some
    state machine? Answer to some API?

    Return the XML to send back to the originating device.

  """
  def event( entry, header, device_id ) do
    Logger.debug("SetParameterValuesResponse detected: #{inspect(device_id)}")

    ""
  end
end
