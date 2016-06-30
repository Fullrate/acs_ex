defmodule ACSRebooTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import Mock

  @sample_response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:RebootResponse />
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|

  test "queue Reboot" do
    # Use mock to make the code pop from Mock instead of actual redis
    with_mock Redix, [command: fn(_pid,_cmd) -> {:ok,"{\"args\": [], \"dispatch\": \"Reboot\", \"source\": \"TEST\"}"} end] do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie)
      assert resp.status_code == 200

      # Parse the Reboot received
      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      assert pres == :ok

      # header id is now in: parsed.header.id

      # Send a Response to end it. Should return "", end session by sending "" back
      reboot_response=to_string(:io_lib.format(@sample_response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(reboot_response,cookie)
      assert resp.body == ""
      assert resp.status_code == 200
    end
  end

end
