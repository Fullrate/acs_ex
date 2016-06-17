defprotocol Trigger do
  def event(entry,header,deviceid)
end
