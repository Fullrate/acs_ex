defmodule ACSCancelTransferTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders

  @response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:CancelTransferResponse />
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|


  test "queue CancelTransfer" do
    # Install a Session Script that send's the GetOptions
    Application.put_env(:acs_ex, :session_script, ACS.Test.Sessions.CancelTransfer, persistent: false)

    {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
    assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
    assert resp.status_code == 200
    {:ok,resp,cookie} = sendStr("",cookie) # This should cause a CancelTransfer request
    assert resp.status_code == 200

    {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
    if pres != :ok do
      IO.inspect("CancelTransfer #{pres} #{resp.body}")
    end
    assert pres == :ok

    # header id is now in: parsed.header.id

    # assert values are what we expect them to be.
    assert hd(parsed.entries).commandkey == "CommandKey"

    assert Supervisor.count_children(:session_supervisor).active == 1

    # Send a Response to end it. Should return "", end session by sending "" back
    response=to_string(:io_lib.format(@response,[parsed.header.id]))
    {:ok,resp,_} = sendStr(response,cookie)
    assert resp.body == ""
    assert resp.status_code == 200
    assert Supervisor.count_children(:session_supervisor).active == 0

    Application.delete_env(:acs_ex, :session_script)
  end

end # of test module

defmodule ACS.Test.Sessions.CancelTransfer do

  import ACS.Session.Script.Vendor.Helpers

  def start(session, _deviceid, _inform) do
    _r=cancelTransfer(session, "CommandKey")
  end

end

