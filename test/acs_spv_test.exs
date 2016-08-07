defmodule ACSSetParameterValuesTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers

  @spv_sample_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-0" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:SetParameterValuesResponse>
\t\t\t<Status>0</Status>
\t\t</cwmp:SetParameterValuesResponse>
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|

  test "queue SetParameterValues" do
    acsex(ACS.Test.Sessions.SingleSetParameterValues) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie) # This should cause a GetParameterValue response
      assert resp.status_code == 200

      # Parse the response received
      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      if ( pres != :ok ) do
        IO.inspect("SPV #{pres} #{resp.body}")
      end
      assert pres == :ok

      # IO.inspect(parsed.header.id)

      # assert values are what we expect them to be.
      params=for p <- hd(parsed.entries).parameters, do: {p.name,p.value}
      params_map=Enum.into(params, %{})

      assert Map.has_key?(params_map,"Device.Test")
      assert Map.has_key?(params_map,"Device.Test2")
      assert params_map["Device.Test"] == "SomeValue"
      assert params_map["Device.Test2"] == "1"

      assert Supervisor.count_children(:session_supervisor).active == 1

      # Send a Response to end it. Should return "", end session by sending "" back
      spv_response=to_string(:io_lib.format(@spv_sample_response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(spv_response,cookie)
      assert resp.body == ""
      assert resp.status_code == 200
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

  test "queue SetParameterValues, bogus args" do
    acsex(ACS.Test.Sessions.SingleSetParameterValuesBogus) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200
      assert Supervisor.count_children(:session_supervisor).active == 1
      {:ok,resp,_cookie} = sendStr("",cookie) # This should cause an attempt to send the SetParameterValue response
                                           # but it will fail and be unnoticable from the Plug. So the plug will end up waiting
                                           # and the SS will terminate, forcing the session to end. So at the end of all
                                           # this mumbo jumbo, we will get "" back
      assert resp.status_code == 200
      assert resp.body == ""
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end
end

defmodule ACS.Test.Sessions.SingleSetParameterValues do

  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _device_id, _inform) do
    _r=setParameterValues(session, [%{name: "Device.Test", type: "xsd:string", value: "SomeValue"},
                                    %{name: "Device.Test2", type: "xsd:int", value: "1"}])
  end

end
defmodule ACS.Test.Sessions.SingleSetParameterValuesBogus do

  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _device_id, _inform) do
    _r=setParameterValues(session, [])
  end

end
