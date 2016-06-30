defmodule ACSSetParameterValuesTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import Mock

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
    # queue something, so that the server will dequeue it. clear queue first.
    with_mock Redix, [command: fn(_pid,_cmd) -> {:ok,"{\"args\": [{\"name\": \"Device.Test\", \"type\": \"xsd:string\", \"value\": \"SomeValue\"}, {\"name\": \"Device.Test2\", \"type\": \"xsd_int\", \"value\": \"1\"}], \"dispatch\": \"SetParameterValues\", \"source\": \"TEST\"}"} end] do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie)
      assert resp.status_code == 200

      # Parse the response received
      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      assert pres == :ok

      # IO.inspect(parsed.header.id)

      # assert values are what we expect them to be.
      params=for p <- hd(parsed.entries).parameters, do: {p.name,p.value}
      params_map=Enum.into(params, %{})

      assert Map.has_key?(params_map,"Device.Test")
      assert Map.has_key?(params_map,"Device.Test2")
      assert params_map["Device.Test"] == "SomeValue"
      assert params_map["Device.Test2"] == "1"

      # Send a Response to end it. Should return "", end session by sending "" back
      gpv_response=to_string(:io_lib.format(@spv_sample_response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(gpv_response,cookie)
      # resp should no be "", send "" back
      assert resp.body == ""
      assert resp.status_code == 200
    end
  end

  test "queue SetParameterValues, bogus args" do
    # queue something, so that the server will dequeue it. clear queue first.
    with_mock Redix, [command: fn(_pid,_cmd) -> {:ok,"{\"args\": [{\"name\": \"Device.Test\", \"value\": \"SomeValue\"}], \"dispatch\": \"SetParameterValues\", \"source\": \"TEST\"}"} end] do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200
      {:ok,resp,_cookie} = sendStr("",cookie)
      assert resp.status_code == 200
      assert resp.body == "" # because bogus args are ignored
    end

    with_mock Redix, [command: fn(_pid,_cmd) -> {:ok,"{\"args\": [], \"dispatch\": \"SetParameterValues\", \"source\": \"TEST\"}"} end] do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200
      {:ok,resp,_cookie} = sendStr("",cookie)
      assert resp.status_code == 200
      assert resp.body == "" # because bogus args are ignored
    end

    with_mock Redix, [command: fn(_pid,_cmd) -> {:ok,"{\"args\": \"foo\", \"dispatch\": \"SetParameterValues\", \"source\": \"TEST\"}"} end] do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
      assert resp.status_code == 200
      {:ok,resp,_cookie} = sendStr("",cookie)
      assert resp.status_code == 200
      assert resp.body == "" # because bogus args are ignored
    end

  end

end
