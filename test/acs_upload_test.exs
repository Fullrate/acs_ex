defmodule ACSUploadTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers

  @upload_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:UploadResponse>
\t\t\t<Status>0</Status>
\t\t\t<StartTime>2015-01-19T23:08:24+00:00</StartTime>
\t\t\t<CompleteTime>2015-01-19T23:18:24+00:00</CompleteTime>
\t\t</cwmp:UploadResponse>
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|


  test "queue Upload" do
    acsex(ACS.Test.Sessions.Upload) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie) # This should cause a Download request
      assert resp.status_code == 200

      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      if pres != :ok do
        IO.inspect("Upload #{pres} #{resp.body}")
      end
      assert pres == :ok

      # header id is now in: parsed.header.id

      # assert values are what we expect them to be.
      assert hd(parsed.entries).url == "http://somewhere.example.com/somefile"
      assert hd(parsed.entries).filetype == "1 Firmware Image"
      assert hd(parsed.entries).commandkey == "key"

      assert Supervisor.count_children(:session_supervisor).active == 1

      # Send a Response to end it. Should return "", end session by sending "" back
      upload_response=to_string(:io_lib.format(@upload_response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(upload_response,cookie)
      assert resp.body == ""
      assert resp.status_code == 200
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

  test "queue Upload with bogus parameters" do
    acsex(ACS.Test.Sessions.UploadBogusParams) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200

      {:ok,resp,_cookie} = sendStr("",cookie) # This should cause the Bogus Upload request
      assert resp.status_code == 200
      assert resp.body == "" # since the Download was bogus, we expect the session to just end.
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

end # of test module

defmodule ACS.Test.Sessions.Upload do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=upload(session, %{
      url: "http://somewhere.example.com/somefile",
      filetype: "1 Firmware Image",
      commandkey: "key"})
  end

end

defmodule ACS.Test.Sessions.UploadBogusParams do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=upload(session, %{
      furl: "bogus"})
  end

end
