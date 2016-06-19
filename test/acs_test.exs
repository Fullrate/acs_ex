defmodule ACSTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  doctest ACS

  test "bogus xml" do
    {:ok,resp,_} = sendStr("bogus")
    # parse error yields, 400
    assert resp.body == "Error handling request" && resp.status_code == 400
  end

  @sample ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2010yy01/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">1189711373</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:InformResponse>
\t\t\t<MaxEnvelopes>1</MaxEnvelopes>
\t\t</cwmp:InformResponse>
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|

  test "plain InformResponse" do
    {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
    assert resp.body == @sample && resp.status_code == 200
    {:ok,resp,_} = sendStr("",cookie)
    assert resp.body == "" && resp.status_code == 200
  end

end
