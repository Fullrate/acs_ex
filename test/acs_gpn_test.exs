defmodule ACSGetParameterNamesTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers

  @gpn_sample_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:GetParameterNamesResponse>
\t\t\t<ParameterList SOAP-ENC:arrayType="cwmp:ParameterInfoStruct[1]">
\t\t\t\t<ParameterInfoStruct>
\t\t\t\t\t<Name>Device.Test.Foo</Name>
\t\t\t\t\t<Writable>1</Writable>
\t\t\t\t</ParameterInfoStruct>
\t\t\t</ParameterList>
\t\t</cwmp:GetParameterNamesResponse>
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|


  test "queue GetParameterNames" do
    acsex(ACS.Test.Sessions.SingleGetParameterNames) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert compare_envelopes(resp.body, readFixture!(fixture_path("informs/plain1_response"))) == {:ok, :match}
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie) # This should cause a GetParameterValue response
      assert resp.status_code == 200

      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      if pres != :ok do
        IO.inspect("GPN #{pres} #{resp.body}")
      end
      assert pres == :ok

      # header id is now in: parsed.header.id

      # assert values are what we expect them to be.
      entry=hd(parsed.entries)
      assert entry.parameter_path == "Device.Test.Foo."
      assert entry.next_level == false

      assert Supervisor.count_children(:session_supervisor).active == 1

      # Send a Response to end it. Should return "", end session by sending "" back
      gpn_response=to_string(:io_lib.format(@gpn_sample_response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(gpn_response,cookie)
      assert resp.body == ""
      assert resp.status_code == 204
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

  test "queue GetParameterNames, bogus params" do
    acsex(ACS.Test.Sessions.SingleGetParameterNamesBogus) do
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

defmodule ACS.Test.Sessions.SingleGetParameterNames do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=getParameterNames(session, %{parameter_path: "Device.Test.Foo.", next_level: false})
  end

end

defmodule ACS.Test.Sessions.SingleGetParameterNamesBogus do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=getParameterNames(session, %{foo: "bar"})
  end

end
