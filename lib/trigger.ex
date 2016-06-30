defprotocol Trigger do
  def event(entry,header,serial)
end
