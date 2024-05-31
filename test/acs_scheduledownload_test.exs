defmodule ACSScheduleDownloadTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers

  @download_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:ScheduleDownloadResponse />
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|


  test "queue ScheduleDownload" do
    acsex(ACS.Test.Sessions.ScheduleDownload) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert compare_envelopes(resp.body, readFixture!(fixture_path("informs/plain1_response"))) == {:ok, :match}
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie) # This should cause a ScheduleDownload request
      assert resp.status_code == 200

      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      if pres != :ok do
        IO.inspect("ScheduleDownload #{pres} #{resp.body}")
      end
      assert pres == :ok

      # header id is now in: parsed.header.id

      # assert values are what we expect them to be.
      assert hd(parsed.entries).url == "http://example.com"
      assert hd(parsed.entries).filetype == "1 Firmware Upgrade Image"
      assert hd(parsed.entries).filesize == 100
      tw=hd(hd(parsed.entries).timewindowlist)
      assert tw.__struct__ == CWMP.Protocol.Messages.TimeWindowStruct
      assert tw.window_start == 5

      assert Supervisor.count_children(:session_supervisor).active == 1

      # Send a Response to end it. Should return "", end session by sending "" back
      download_response=to_string(:io_lib.format(@download_response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(download_response,cookie)
      assert resp.body == ""
      assert resp.status_code == 204
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

  test "queue ScheduleDownload with bogus parameters" do
    acsex(ACS.Test.Sessions.ScheduleDownloadBogusParams) do
     {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
     assert compare_envelopes(resp.body, readFixture!(fixture_path("informs/plain1_response"))) == {:ok, :match}
     assert resp.status_code == 200

     {:ok,resp,_cookie} = sendStr("",cookie) # This should cause the Bogus ScheduleDownload request
     assert resp.status_code == 204
     assert resp.body == "" # since the Download was bogus, we expect the session to just end.
     assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

end # of test module

defmodule ACS.Test.Sessions.ScheduleDownload do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=scheduleDownload(session, %{
        filetype: "1 Firmware Upgrade Image",
        url: "http://example.com",
        filesize: 100,
        timewindowlist: [%{
          window_start: 5,
          window_end: 45,
          window_mode: "1 At Any Time",
          user_message: "",
          max_retries: -1}]})
  end

end

defmodule ACS.Test.Sessions.ScheduleDownloadBogusParams do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=scheduleDownload(session, %{
      furl: "bogus"})
  end

end
