defimpl Trigger, for: CWMP.Protocol.Messages.GetParameterValuesResponse do
  require Logger
  @doc """
    GetParameterValuesResponse comes in here. This is where you implement
    what is to happen in the arrival of this messages. Maybe
    store the result somewhere? This would be the place to implement
    that.

    Return the XML to send back to the originating device.

  """
  def event( entry, header, device_id ) do
    Logger.debug("GetParameterValuesResponse detected: #{inspect(device_id)}")

    ""
  end
end
