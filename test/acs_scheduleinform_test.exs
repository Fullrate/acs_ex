defmodule ACSScheduleInformTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers

  @sample_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:ScheduleInformResponse />
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|


  test "queue ScheduleInform" do
    acsex(ACS.Test.Sessions.ScheduleInform) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie) # This should cause a Download request
      assert resp.status_code == 200

      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      if pres != :ok do
        IO.inspect("ScheduleInform #{pres} #{resp.body}")
      end
      assert pres == :ok

      # header id is now in: parsed.header.id

      # assert values are what we expect them to be.
      assert hd(parsed.entries).delay_seconds == 5
      assert hd(parsed.entries).commandkey == "KEY"

      assert Supervisor.count_children(:session_supervisor).active == 1

      # Send a Response to end it. Should return "", end session by sending "" back
      response=to_string(:io_lib.format(@sample_response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(response,cookie)
      assert resp.body == ""
      assert resp.status_code == 200
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

  test "queue ScheduleInform with bogus parameters" do
    acsex(ACS.Test.Sessions.ScheduleInformBogus) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200

      {:ok,resp,_cookie} = sendStr("",cookie) # This should cause the Bogus Download request
      assert resp.status_code == 200
      assert resp.body == "" # since the Download was bogus, we expect the session to just end.
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

end # of test module

defmodule ACS.Test.Sessions.ScheduleInform do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=scheduleInform(session, %{
      commandkey: "KEY",
      delay_seconds: 5})
  end

end

defmodule ACS.Test.Sessions.ScheduleInformBogus do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=scheduleInform(session, %{
      foo: "bogus"})
  end

end
