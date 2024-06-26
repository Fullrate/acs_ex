defmodule ACSGetParameterAttributesTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers

  @gpa_sample_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:GetParameterAttributesResponse>
\t\t\t<ParameterList SOAP-ENC:arrayType="cwmp:ParameterAttributeStruct[2]">
\t\t\t\t<ParameterAttributeStruct>
\t\t\t\t\t<Name>Device.Test.Foo</Name>
\t\t\t\t\t<Notification>1</Notification>
\t\t\t\t\t<AccessList>
\t\t\t\t\t\t<string>Subscriber</string>
\t\t\t\t\t</AccessList>
\t\t\t\t</ParameterAttributeStruct>
\t\t\t\t<ParameterAttributeStruct>
\t\t\t\t\t<Name>Device.Test.Bar</Name>
\t\t\t\t\t<Notification>1</Notification>
\t\t\t\t\t<AccessList>
\t\t\t\t\t\t<string>Subscriber</string>
\t\t\t\t\t</AccessList>
\t\t\t\t</ParameterAttributeStruct>
\t\t\t</ParameterList>
\t\t</cwmp:GetParameterAttributesResponse>
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|


  test "queue GetParameterAttributes" do
    acsex(ACS.Test.Sessions.SingleGetParameterAttributes) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert compare_envelopes(resp.body, readFixture!(fixture_path("informs/plain1_response"))) == {:ok, :match}
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie) # This should cause a GetParameterValue response
      assert resp.status_code == 200

      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      if pres != :ok do
        IO.inspect("GPA #{pres} #{resp.body}")
      end
      assert pres == :ok

      # header id is now in: parsed.header.id

      # assert values are what we expect them to be.
      entry=hd(parsed.entries)
      assert entry.parameters == ["Device.Test.Foo","Device.Test.Bar"]

      assert Supervisor.count_children(:session_supervisor).active == 1

      # Send a Response to end it. Should return "", end session by sending "" back
      gpa_response=to_string(:io_lib.format(@gpa_sample_response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(gpa_response,cookie)
      assert resp.body == ""
      assert resp.status_code == 204
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

  test "queue GetParameterAttributes, bogus params" do
    acsex(ACS.Test.Sessions.SingleGetParameterAttributesBogus) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert compare_envelopes(resp.body, readFixture!(fixture_path("informs/plain1_response"))) == {:ok, :match}
      assert resp.status_code == 200
      assert Supervisor.count_children(:session_supervisor).active == 1
      {:ok,resp,_cookie} = sendStr("",cookie) # This should cause an attempt to send the GetParameterValue response
                                           # but it will fail and be unnoticable from the Plug. So the plug will end up waiting
                                           # and the SS will terminate, forcing the session to end. So at the end of all
                                           # this mumbo jumbo, we will get "" back
      assert resp.status_code == 204
      assert resp.body == ""
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

end # of test module

defmodule ACS.Test.Sessions.SingleGetParameterAttributes do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=getParameterAttributes(session, ["Device.Test.Foo", "Device.Test.Bar"])
  end

end

defmodule ACS.Test.Sessions.SingleGetParameterAttributesBogus do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=getParameterAttributes(session, [])
  end

end
