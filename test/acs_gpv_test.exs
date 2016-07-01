defmodule ACSGetParameterValuesTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders

  @gpv_sample_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:GetParameterValuesResponse>
<ParameterList xsi:type="SOAP-ENC:Array" SOAP-ENC:arrayType="cwmp:ParameterValueStruct[2]">
                                <ParameterValueStruct>
                                        <Name>Device.Test.Foo</Name>
                                        <Value xsi:type="xsd:unsignedInt">1</Value>
                                </ParameterValueStruct>
                        </ParameterList>
\t\t</cwmp:GetParameterValuesResponse>
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|


  test "queue GetParameterValues" do
    # Install a Session Script that send's the GetParameterValues
    Application.put_env(:acs_ex, :session_script, ACS.Test.Sessions.SingleGetParameterValues, persistent: false)

    {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
    assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
    assert resp.status_code == 200
    {:ok,resp,cookie} = sendStr("",cookie) # This should cause a GetParameterValue response
    assert resp.status_code == 200

    {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
    assert pres == :ok

    # header id is now in: parsed.header.id

    # assert values are what we expect them to be.
    assert hd(parsed.entries).parameters == ["Device.Test.Foo"]

    assert Supervisor.count_children(:session_supervisor).active == 1

    # Send a Response to end it. Should return "", end session by sending "" back
    gpv_response=to_string(:io_lib.format(@gpv_sample_response,[parsed.header.id]))
    {:ok,resp,_} = sendStr(gpv_response,cookie)
    assert resp.body == ""
    assert resp.status_code == 200
    assert Supervisor.count_children(:session_supervisor).active == 0
  end

  test "queue GetParameterValues, bogus params" do
    # Install a Session Script that send's the GetParameterValues
    Application.put_env(:acs_ex, :session_script, ACS.Test.Sessions.SingleGetParameterValuesBogus, persistent: false)

    {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
    assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
    assert resp.status_code == 200
    assert Supervisor.count_children(:session_supervisor).active == 1
    {:ok,resp,cookie} = sendStr("",cookie) # This should cause an attempt to send the GetParameterValue response
                                           # but it will fail and be unnoticable from the Plug. So the plug will end up waiting
                                           # and the SS will terminate, forcing the session to end. So at the end of all
                                           # this mumbo jumbo, we will get "" back
    assert resp.status_code == 200
    assert resp.body == ""
    assert Supervisor.count_children(:session_supervisor).active == 0
  end

end # of test module

defmodule ACS.Test.Sessions.SingleGetParameterValues do

  import ACS.Session.Script.Vendor.Helpers

  def start(session, _device_id, _inform) do
    _r=getParameterValues(session, ["Device.Test.Foo"])
  end

end

defmodule ACS.Test.Sessions.SingleGetParameterValuesBogus do

  import ACS.Session.Script.Vendor.Helpers

  def start(session, _device_id, _inform) do
    _r=getParameterValues(session, [])
  end

end

