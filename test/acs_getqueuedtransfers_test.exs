defmodule ACSGetQueuedTransfersTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers

  @sample_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:GetQueuedTransfersResponse>
        <TransferList SOAP-ENC:arrayType="cwmp:QueuedTransferStruct[2]">
          <QueuedTransferStruct>
            <CommandKey>cmdkey</CommandKey>
            <State>2</State>
          </QueuedTransferStruct>
          <QueuedTransferStruct>
            <CommandKey>cmdkey2</CommandKey>
            <State>3</State>
          </QueuedTransferStruct>
        </TransferList>
\t\t</cwmp:GetQueuedTransfersResponse>
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|

  test "queue GetQueuedTransfers" do
    acsex(ACS.Test.Sessions.SingleGetQueuedTransfers) do
      assert Supervisor.count_children(:session_supervisor).active == 0

      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert compare_envelopes(resp.body, readFixture!(fixture_path("informs/plain1_response"))) == {:ok, :match}
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie) # This should cause a GetParameterValue response
      assert resp.status_code == 200

      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      if pres != :ok do
        IO.inspect("GetQueuedTransfers #{pres} #{resp.body}")
      end
      assert pres == :ok

      # header id is now in: parsed.header.id

      assert hd(parsed.entries).__struct__ == CWMP.Protocol.Messages.GetQueuedTransfers

      assert Supervisor.count_children(:session_supervisor).active == 1

      # Send a Response to end it. Should return "", end session by sending "" back
      gqt_response=to_string(:io_lib.format(@sample_response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(gqt_response,cookie)
      assert resp.body == ""
      assert resp.status_code == 204
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

end

defmodule ACS.Test.Sessions.SingleGetQueuedTransfers do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _device_id, _inform) do
    _r=getQueuedTransfers(session)
  end

end
