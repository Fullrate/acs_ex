defmodule ACSChangeDUStateTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers

  @response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:ChangeDUStateResponse />
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|


  test "queue ChangeDUState" do
    acsex(ACS.Test.Sessions.ChangeDUState) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert compare_envelopes(resp.body, readFixture!(fixture_path("informs/plain1_response"))) == {:ok, :match}
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie) # This should cause a ChangeDUState request
      assert resp.status_code == 200

      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      if pres != :ok do
        IO.inspect("ChangeDUState #{pres} #{resp.body}")
      end
      assert pres == :ok

      # header id is now in: parsed.header.id

      # assert values are what we expect them to be.
      entry=List.first(parsed.entries)
      assert entry.commandkey == "ck"
      assert Map.has_key?(entry,:operations)
      install=List.first(entry.operations)
      assert install.__struct__ == CWMP.Protocol.Messages.InstallOpStruct
      assert install.url == "http://example.com/url"
      uninstall=List.last(entry.operations)
      assert uninstall.__struct__ == CWMP.Protocol.Messages.UninstallOpStruct
      assert uninstall.url == "http://example.com/url"

      assert Supervisor.count_children(:session_supervisor).active == 1

      # Send a Response to end it. Should return "", end session by sending "" back
      response=to_string(:io_lib.format(@response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(response,cookie)
      assert resp.body == ""
      assert resp.status_code == 204
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

  test "queue ChangeDUState with bogus parameters" do
    acsex(ACS.Test.Sessions.ChangeDUStateBogusParams) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert compare_envelopes(resp.body, readFixture!(fixture_path("informs/plain1_response"))) == {:ok, :match}
      assert resp.status_code == 200

      {:ok,resp,_cookie} = sendStr("",cookie) # This should cause the Bogus ChangeDUState request
      assert resp.status_code == 204
      assert resp.body == "" # since the ChangeDUState was bogus, we expect the session to just end.
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

end # of test module

defmodule ACS.Test.Sessions.ChangeDUState do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=changeDUState(session, %{
        commandkey: "ck",
        operations: [%CWMP.Protocol.Messages.InstallOpStruct{
            url: "http://example.com/url",
            uuid: "bla-foo-abcd-1234",
            username: "user",
            password: "pass",
            execution_env_ref: "foo"},
          %CWMP.Protocol.Messages.UninstallOpStruct{
            url: "http://example.com/url",
            uuid: "bla-foo-abcd-1234",
            execution_env_ref: "foo"}]})
  end

end

defmodule ACS.Test.Sessions.ChangeDUStateBogusParams do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=changeDUState(session, %{
      furl: "bogus"})
  end

end
