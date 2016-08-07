defmodule ACSGetAllQueuedTransfersTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers

  @sample_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:GetAllQueuedTransfersResponse>
\t\t\t<TransferList SOAP-ENC:arrayType="cwmp:AllQueuedTransferStruct[2]">
\t\t\t\t<AllQueuedTransferStruct>
\t\t\t\t\t<CommandKey>cmdkey</CommandKey>
\t\t\t\t\t<State>1</State>
\t\t\t\t\t<IsDownload>1</IsDownload>
\t\t\t\t\t<FileType>1 Firmware Upgrade Image</FileType>
\t\t\t\t\t<FileSize>123456</FileSize>
\t\t\t\t\t<TargetFileName>image</TargetFileName>
\t\t\t\t</AllQueuedTransferStruct>
\t\t\t\t<AllQueuedTransferStruct>
\t\t\t\t\t<CommandKey>cmdkey2</CommandKey>
\t\t\t\t\t<State>3</State>
\t\t\t\t\t<IsDownload>0</IsDownload>
\t\t\t\t\t<FileType>2 Web Content</FileType>
\t\t\t\t\t<FileSize>654321</FileSize>
\t\t\t\t\t<TargetFileName/>
\t\t\t\t</AllQueuedTransferStruct>
\t\t\t</TransferList>
\t\t</cwmp:GetAllQueuedTransfersResponse>
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|

  test "queue GetAllQueuedTransfers" do
    acsex(ACS.Test.Sessions.SingleGetAllQueuedTransfers) do
      assert Supervisor.count_children(:session_supervisor).active == 0

      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie) # This should cause a GetAllQueuedTransfers response
      assert resp.status_code == 200

      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      if pres != :ok do
        IO.inspect("GetAllQueuedTransfers #{pres} #{resp.body}")
      end
      assert pres == :ok

      # header id is now in: parsed.header.id

      assert hd(parsed.entries).__struct__ == CWMP.Protocol.Messages.GetAllQueuedTransfers

      assert Supervisor.count_children(:session_supervisor).active == 1

      # Send a Response to end it. Should return "", end session by sending "" back
      response=to_string(:io_lib.format(@sample_response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(response,cookie)
      assert resp.body == ""
      assert resp.status_code == 200
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

end

defmodule ACS.Test.Sessions.SingleGetAllQueuedTransfers do

  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _device_id, _inform) do
    _r=getAllQueuedTransfers(session)
  end

end
