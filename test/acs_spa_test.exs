defmodule ACSSetParameterAttributesTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers

  @spa_sample_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:SetParameterAttributesResponse/>
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|


  test "queue SetParameterAttributes" do
    acsex(ACS.Test.Sessions.SingleSetParameterAttributes) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie) # This should cause a SetParameterAttributes request
      assert resp.status_code == 200

      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      if pres != :ok do
        IO.inspect("SPA #{pres} #{resp.body}")
      end
      assert pres == :ok

      # header id is now in: parsed.header.id
      # assert values are what we expect them to be.
      entry=hd(parsed.entries)
      assert is_list(entry.parameters)
      params = hd(entry.parameters)
      assert params.name == "Device.Test.Foo"
      assert params.notification_change == false
      assert params.notification == 2
      assert params.accesslist_change == true
      assert params.accesslist == ["Subscriber"]

      assert Supervisor.count_children(:session_supervisor).active == 1

      # Send a Response to end it. Should return "", end session by sending "" back
      spa_response=to_string(:io_lib.format(@spa_sample_response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(spa_response,cookie)
      assert resp.body == ""
      assert resp.status_code == 200
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

  test "queue SetParameterAttributes, bogus params" do
    acsex(ACS.Test.Sessions.SingleSetParameterAttributesBogus) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200
      assert Supervisor.count_children(:session_supervisor).active == 1
      {:ok,resp,_cookie} = sendStr("",cookie) # This should cause an attempt to send the GetParameterValue response
                                           # but it will fail and be unnoticable from the Plug. So the plug will end up waiting
                                           # and the SS will terminate, forcing the session to end. So at the end of all
                                           # this mumbo jumbo, we will get "" back
      assert resp.status_code == 200
      assert resp.body == ""
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

end # of test module

defmodule ACS.Test.Sessions.SingleSetParameterAttributes do

  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=setParameterAttributes(session, [%{
      name: "Device.Test.Foo",
      notification_change: false,
      notification: 2,
      accesslist_change: true,
      accesslist: ["Subscriber"]
    }])
  end

end

defmodule ACS.Test.Sessions.SingleSetParameterAttributesBogus do

  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=setParameterAttributes(session, %{foo: "bar"})
  end

end

