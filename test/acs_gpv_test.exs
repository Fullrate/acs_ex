defmodule ACSGetParameterValuesTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import Mock

  @gpv_sample_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:GetParameterValuesResponse>
<ParameterList xsi:type="SOAP-ENC:Array" SOAP-ENC:arrayType="cwmp:ParameterValueStruct[2]">
                                <ParameterValueStruct>
                                        <Name>Device.Test</Name>
                                        <Value xsi:type="xsd:unsignedInt">1</Value>
                                </ParameterValueStruct>
                                <ParameterValueStruct>
                                        <Name>Device.Test2</Name>
                                        <Value xsi:type="xsd:string">foo</Value>
                                </ParameterValueStruct>
                        </ParameterList>
\t\t</cwmp:GetParameterValuesResponse>
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|

  test "queue GetParameterValues" do
    # Use mock to make the code pop from Mock instead of actual redis
    with_mock Redix, [command: fn(_pid,_cmd) -> {:ok,"{\"args\": [{\"name\": \"Device.Test\", \"type\": \"string\"}, {\"name\": \"Device.Test2\", \"type\": \"string\"}], \"dispatch\": \"GetParameterValues\", \"source\": \"TEST\"}"} end] do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie)
      assert resp.status_code == 200

      # resp.body should now be a GetParameterValues request with the data
      # Mock'ed in
      # Parse the GetParameterValues received
      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      assert pres == :ok

      # header id is now in: parsed.header.id

      # assert values are what we expect them to be.
      assert hd(parsed.entries).parameters == ["Device.Test", "Device.Test2"]

      # Send a Response to end it. Should return "", end session by sending "" back
      gpv_response=to_string(:io_lib.format(@gpv_sample_response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(gpv_response,cookie)
      assert resp.body == ""
      assert resp.status_code == 200
    end
  end

end
