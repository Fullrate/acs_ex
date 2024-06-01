defmodule ACSGetOptionsTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers

  @response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:GetOptionsResponse>
\t\t\t<OptionList SOAP-ENC:arrayType="cwmp:OptionStruct[1]">
\t\t\t\t<OptionStruct>
\t\t\t\t\t<OptionName>Some Option</OptionName>
\t\t\t\t\t<VoucherSN>12345678</VoucherSN>
\t\t\t\t\t<State>1</State>
\t\t\t\t\t<Mode>1</Mode>
\t\t\t\t\t<StartDate>2015-01-10T23:45:12+00:00</StartDate>
\t\t\t\t\t<ExpirationDate>2015-01-10T23:45:12+00:00</ExpirationDate>
\t\t\t\t\t<IsTransferable>1</IsTransferable>
\t\t\t\t</OptionStruct>
\t\t\t</OptionList>
\t\t</cwmp:GetOptionsResponse>
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|


  test "queue GetOptions" do
    acsex(ACS.Test.Sessions.GetOptions) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert compare_envelopes(resp.body, readFixture!(fixture_path("informs/plain1_response"))) == {:ok, :match}
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie) # This should cause a Download request
      assert resp.status_code == 200

      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      if pres != :ok do
        IO.inspect("Download #{pres} #{resp.body}")
      end
      assert pres == :ok

      # header id is now in: parsed.header.id

      # assert values are what we expect them to be.
      assert hd(parsed.entries).option_name == "Some Option"

      assert Supervisor.count_children(:session_supervisor).active == 1

      # Send a Response to end it. Should return "", end session by sending "" back
      response=to_string(:io_lib.format(@response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(response,cookie)
      assert resp.body == ""
      assert resp.status_code == 204
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end



end # of test module

defmodule ACS.Test.Sessions.GetOptions do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=getOptions(session, "Some Option")
  end

end
