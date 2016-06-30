defimpl Trigger, for: CWMP.Protocol.Messages.Inform do
  require Logger
  @doc """
    Inform comes in here. This is where you implement
    what is to happen in the arrival of an inform.

    Return the XML to send back to the originating device.

  """
  def event( entry, header, device_id ) do
    Logger.debug("inform detected: #{inspect(device_id)}")
    Logger.debug("inform header: #{inspect(header)}")
    Logger.debug("inform entry: #{inspect(entry)}")

    CWMP.Protocol.Generator.generate!(
      %CWMP.Protocol.Messages.Header{id: header.id},
      %CWMP.Protocol.Messages.InformResponse{
        max_envelopes: 1}, device_id.cwmp_version)
  end
end
