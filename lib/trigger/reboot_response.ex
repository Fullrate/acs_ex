defimpl Trigger, for: CWMP.Protocol.Messages.RebootResponse do
  require Logger
  @doc """
    RebootResponse comes in here. This is where you implement
    what is to happen in the arrival of this messages. Maybe
    update some statemachine or something?

    Return the XML to send back to the originating device.

  """
  def event( _entry, _header, device_id ) do
    Logger.debug("RebootResponse detected: #{inspect(device_id)}")
    ""
  end
end
