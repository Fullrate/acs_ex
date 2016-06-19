defmodule ACSTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders

  @gpv_sample ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">([a-f0-9]+)</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:GetParameterValues>
\t\t\t<ParameterNames>
\t\t\t\t<string>Device.Test</string>
\t\t\t\t<string>Device.Test2</string>
\t\t\t</ParameterNames>
\t\t</cwmp:GetParameterValues>
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|

  @gpv_sample_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2010yy01/XMLSchema-instance">
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
    # queue something, so that the server will dequeue it. TODO, clear queue first.
    ACS.Queue.dequeue_all("SerialNo1")
    ACS.Queue.enqueue("SerialNo1", "GetParameterValues", [%CWMP.Protocol.Messages.GetParameterValuesStruct{name: "Device.Test", type: "string"}, %CWMP.Protocol.Messages.GetParameterValuesStruct{name: "Device.Test2", type: "string"}], "TEST")
    {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
    assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
    assert resp.status_code == 200
    {:ok,resp,cookie} = sendStr("",cookie)
    assert resp.status_code == 200
    {res,regex} = Regex.compile(@gpv_sample)
    assert res == :ok
    captures=Regex.run(regex,resp.body,capture: :all)
    case captures do
      [all,id] ->
        # Send a Response to end it. Should return "", end session by sending "" back
        gpv_response=to_string(:io_lib.format(@gpv_sample_response,[id]))
        {:ok,resp,cookie} = sendStr(gpv_response,cookie)
        # resp should no be "", send "" back
        assert resp.body == ""
        assert resp.status_code == 200
      _ -> flunk "no id in header"
    end

  end

end
