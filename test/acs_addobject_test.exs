defmodule ACSAddObjectTest do
  use ExUnit.Case, async: false
  import TestHelpers
  import PathHelpers
  import RequestSenders

  @ao_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:AddObjectResponse>
\t\t\t<InstanceNumber>1</InstanceNumber>
\t\t\t<Status>0</Status>
\t\t</cwmp:AddObjectResponse>
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|

  test "queue AddObject" do
    acsex(ACS.Test.Sessions.AddObject) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert compare_envelopes(resp.body, readFixture!(fixture_path("informs/plain1_response"))) == {:ok, :match}
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie) # This should cause an AddObject request
      assert resp.status_code == 200

      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      if pres != :ok do
        IO.inspect("AddObject #{pres} #{resp.body}")
      end
      assert pres == :ok

      # header id is now in: parsed.header.id

      # assert values are what we expect them to be.
      assert hd(parsed.entries).object_name == "Device.Test.Foo."

      assert Supervisor.count_children(:session_supervisor).active == 1

      # Send a Response to end it. Should return "", end session by sending "" back
      ao_response=to_string(:io_lib.format(@ao_response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(ao_response,cookie)
      assert resp.body == ""
      assert resp.status_code == 204
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

  test "queue AddObject with bogus parameters" do
    acsex(ACS.Test.Sessions.AddObjectParams) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert compare_envelopes(resp.body, readFixture!(fixture_path("informs/plain1_response"))) == {:ok, :match}
      assert resp.status_code == 200

      {:ok,resp,_cookie} = sendStr("",cookie) # This should cause the Bogus AddObject request
      assert resp.status_code == 204
      assert resp.body == "" # since the AddObject was bogus, we expect the session to just end.
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

end # of test module

defmodule ACS.Test.Sessions.AddObject do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=addObject(session, %{object_name: "Device.Test.Foo."})
  end

end

defmodule ACS.Test.Sessions.AddObjectParams do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=addObject(session, %{foo: "bogus"})
  end

end
