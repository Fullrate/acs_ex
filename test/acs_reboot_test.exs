defmodule ACSRebootTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import Mock

  @sample_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:RebootResponse />
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|

  test "queue Reboot" do
    assert Supervisor.count_children(:session_supervisor).active == 0
    # Install a Session Script that send's the Reboot
    Application.put_env(:acs_ex, :session_script, ACS.Test.Sessions.SingleReboot, persistent: false)

    {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
    assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
    assert resp.status_code == 200
    {:ok,resp,cookie} = sendStr("",cookie) # This should cause a GetParameterValue response
    assert resp.status_code == 200

    {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
    assert pres == :ok

    # header id is now in: parsed.header.id

    assert hd(parsed.entries).__struct__ == CWMP.Protocol.Messages.Reboot

    assert Supervisor.count_children(:session_supervisor).active == 1

    # Send a Response to end it. Should return "", end session by sending "" back
    reboot_response=to_string(:io_lib.format(@sample_response,[parsed.header.id]))
    {:ok,resp,_} = sendStr(reboot_response,cookie)
    assert resp.body == ""
    assert resp.status_code == 200
    assert Supervisor.count_children(:session_supervisor).active == 0
  end

end

defmodule ACS.Test.Sessions.SingleReboot do

  import ACS.Session.Script.Vendor.Helpers

  def start(session, _device_id, _inform) do
    _r=reboot(session)
  end

end
