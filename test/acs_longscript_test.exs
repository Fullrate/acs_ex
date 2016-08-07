defmodule ACSLongSessionScriptTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers
  doctest ACS

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

  test "GetParameterValues with long initial running script" do
    acsex(ACS.Test.LongGetParameterValues) do
      assert Supervisor.count_children(:session_supervisor).active == 0
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200
      {:ok,resp,_} = sendStr("",cookie)

      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      if pres != :ok do
        IO.inspect("Long GPV #{pres} #{resp.body}")
      end
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
  end

end

defmodule ACS.Test.LongGetParameterValues do

  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    Process.sleep(1000)
    _r=getParameterValues(session, ["Device.Test.Foo"])
  end

end
