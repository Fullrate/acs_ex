defmodule ACSTestSession do
  use ExUnit.Case
  import TestHelpers

  @moduledoc """

  Tests the GenServer that takes care of the sessions. Getting to
  the edge conditions is not easy with real requests, so we just
  call the handles here.

  """

  @session_id "1234567901234567890123456789012"
  @device_id %{manufacturer: "ZyXEL", oui: "4C9EFF", product_class: "Product1", serial_number: "SerialNo1", ip: "127.0.0.1"}
  @transfer_complete %{cwmp_version: "1-0", entries: [%CWMP.Protocol.Messages.TransferComplete{command_key: "", complete_time: Timex.datetime({{2016,5,18},{8,6,3}}), fault_struct: %CWMP.Protocol.Messages.FaultStruct{code: 0, string: "Download successful"}, start_time: Timex.datetime({{2016,5,18},{8,6,3}})}], header: %CWMP.Protocol.Messages.Header{hold_requests: false, id: "12345678", no_more_requests: false, session_timeout: 30}}
  @tc_inform %{cwmp_version: "1-0", entries: [%CWMP.Protocol.Messages.Inform{current_time: Timex.datetime({{2016,5,18},{8,6,3}}), device_id: %CWMP.Protocol.Messages.DeviceIdStruct{manufacturer: "ZyXEL", oui: "4C9EFF", product_class: "Product1", serial_number: "SerialNo1"}, events: [%CWMP.Protocol.Messages.EventStruct{code: "7 TRANSFER COMPLETE", command_key: ""}], max_envelopes: 1, parameters: [%CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.DeviceSummary", type: "xsd:string", value: "InternetGatewayDevice:1.4[](Baseline:1, EthernetLAN:1, Time:1, IPPing:1, DeviceAssociation:1, EthernetWAN:1, VDSL2WAN:1, ADSLWAN:1, ATMLoopback:1, WiFiLAN:1, X_5067F0_TrustDomain:1), VoiceService:1.0[1](Endpoint:1, SIPEndpoint:1)"}, %CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.DeviceInfo.SpecVersion", type: "xsd:string", value: "1.0"}, %CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.DeviceInfo.HardwareVersion", type: "xsd:string", value: "HW_1.0"}, %CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.DeviceInfo.SoftwareVersion", type: "xsd:string", value: "1.00"}, %CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.DeviceInfo.ProvisioningCode", type: "xsd:string", value: ""}, %CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.ManagementServer.ConnectionRequestURL", type: "xsd:string", value: "http://666.666.666.666:1234/foobar"}, %CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.ManagementServer.ParameterKey", type: "xsd:string", value: ""}, %CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.WANDevice.2.WANConnectionDevice.1.WANIPConnection.2.ExternalIPAddress", type: "xsd:string", value: "666.666.666.666"}], retry_count: 0}], header:  %CWMP.Protocol.Messages.Header{hold_requests: false, id: "1189711373", no_more_requests: false, session_timeout: 30}}
  @inform %{cwmp_version: "1-0", entries: [%CWMP.Protocol.Messages.Inform{current_time: Timex.datetime({{2016,5,18},{8,6,3}}), device_id: %CWMP.Protocol.Messages.DeviceIdStruct{manufacturer: "ZyXEL", oui: "4C9EFF", product_class: "Product1", serial_number: "SerialNo1"}, events: [%CWMP.Protocol.Messages.EventStruct{code: "2 PERIODIC", command_key: ""}], max_envelopes: 1, parameters: [%CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.DeviceSummary", type: "xsd:string", value: "InternetGatewayDevice:1.4[](Baseline:1, EthernetLAN:1, Time:1, IPPing:1, DeviceAssociation:1, EthernetWAN:1, VDSL2WAN:1, ADSLWAN:1, ATMLoopback:1, WiFiLAN:1, X_5067F0_TrustDomain:1), VoiceService:1.0[1](Endpoint:1, SIPEndpoint:1)"}, %CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.DeviceInfo.SpecVersion", type: "xsd:string", value: "1.0"}, %CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.DeviceInfo.HardwareVersion", type: "xsd:string", value: "HW_1.0"}, %CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.DeviceInfo.SoftwareVersion", type: "xsd:string", value: "1.00"}, %CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.DeviceInfo.ProvisioningCode", type: "xsd:string", value: ""}, %CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.ManagementServer.ConnectionRequestURL", type: "xsd:string", value: "http://666.666.666.666:1234/foobar"}, %CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.ManagementServer.ParameterKey", type: "xsd:string", value: ""}, %CWMP.Protocol.Messages.ParameterValueStruct{name: "InternetGatewayDevice.WANDevice.2.WANConnectionDevice.1.WANIPConnection.2.ExternalIPAddress", type: "xsd:string", value: "666.666.666.666"}], retry_count: 0}], header:  %CWMP.Protocol.Messages.Header{hold_requests: false, id: "1189711373", no_more_requests: false, session_timeout: 30}}
  @inform_response "<SOAP-ENV:Envelope xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:cwmp=\"urn:dslforum-org:cwmp-1-0\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n\t<SOAP-ENV:Header>\n\t\t<cwmp:ID SOAP-ENV:mustUnderstand=\"1\">1189711373</cwmp:ID>\n\t</SOAP-ENV:Header>\n\t<SOAP-ENV:Body>\n\t\t<cwmp:InformResponse>\n\t\t\t<MaxEnvelopes>1</MaxEnvelopes>\n\t\t</cwmp:InformResponse>\n\t</SOAP-ENV:Body>\n</SOAP-ENV:Envelope>"
  @empty %{}
  @gpv_request ~r"<SOAP-ENV:Envelope xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:cwmp=\"urn:dslforum-org:cwmp-1-0\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n\t<SOAP-ENV:Header>\n\t\t<cwmp:ID SOAP-ENV:mustUnderstand=\"1\">[a-f0-9]+</cwmp:ID>\n\t</SOAP-ENV:Header>\n\t<SOAP-ENV:Body>\n\t\t<cwmp:GetParameterValues>\n\t\t\t<ParameterNames>\n\t\t\t\t<string>Device.Test.</string>\n\t\t\t</ParameterNames>\n\t\t</cwmp:GetParameterValues>\n\t</SOAP-ENV:Body>\n</SOAP-ENV:Envelope>"
  @gpv_response  %{
    cwmp_version: "1-0",
    entries: [
      %CWMP.Protocol.Messages.GetParameterValuesResponse{ parameters: [
        %CWMP.Protocol.Messages.ParameterValueStruct{name: "Device.Test.A", type: "xsd:string", value: "1.0"},
        %CWMP.Protocol.Messages.ParameterValueStruct{name: "Device.Test.B", type: "xsd:string", value: "foo"}]
      }],
    header:  %CWMP.Protocol.Messages.Header{hold_requests: false, id: "df53368c23d71f15b339cf4b9c1ca2ed", no_more_requests: false, session_timeout: 30}
  }
  @download_response %{
    cwmp_version: "1-0",
    entries: [
      %CWMP.Protocol.Messages.DownloadResponse{
        status: 0,
        complete_time: %Timex.DateTime{calendar: :gregorian,
          day: 19, hour: 23, minute: 9, month: 1, millisecond: 0, second: 24,
          timezone: %Timex.TimezoneInfo{abbreviation: "UTC", from: :min,
            full_name: "UTC", offset_std: 0, offset_utc: 0, until: :max}, year: 2015},
        start_time: %Timex.DateTime{calendar: :gregorian,
          day: 19, hour: 23, minute: 8, month: 1, millisecond: 0, second: 24,
          timezone: %Timex.TimezoneInfo{abbreviation: "UTC", from: :min,
            full_name: "UTC", offset_std: 0, offset_utc: 0, until: :max}, year: 2015}}],
    header: %CWMP.Protocol.Messages.Header{hold_requests: false, id: "1234567901234567890123456789012",
      session_timeout: 30, no_more_requests: false}}


  #  test "Normal Session" do
    #   {:ok,pid} = ACS.Session.Supervisor.start_session(@device_id, @inform)
    # assert is_pid(pid)

    # now pretend we send the inform into the session, this is what the plug does after creating it
    #   r=ACS.Session.process_message(@device_id, @inform)
    # assert {200,@inform_response} == r

    #r=ACS.Session.process_message(@device_id, @empty)
    # assert r=={200,""}

    #end_res=ACS.Session.Supervisor.end_session(@device_id)
    #assert end_res == :ok
    #end

  test "Normal Session - with right ID in response" do
    acsex(ACS.Session.Script.Vendor) do
      {:ok,pid} = ACS.Session.Supervisor.start_session(@session_id, @device_id, @inform, fn(session, _device_id, _message) ->
        import ACS.Session.Script.Vendor.Helpers
        # The script inserts a message in the queue.
        _r = getParameterValues(session, ["Device.Test."])
      end )
      assert is_pid(pid)

      assert Supervisor.count_children(:session_supervisor).active == 1


      assert ACS.Session.verify_session(@session_id, "127.0.0.1")
      assert ACS.Session.verify_session(@session_id, "127.0.0.2") == false

      # now pretend we send the inform into the session, this is what the plug does after creating it
      r=ACS.Session.process_message(@session_id, @inform)
      assert {200,@inform_response} == r

      {code,response}=ACS.Session.process_message(@session_id, @empty)
      assert code==200
      assert Regex.match?(@gpv_request,response)

      {res,parsed} = CWMP.Protocol.Parser.parse(response)
      assert res == :ok

      # another process_message for the response, but with the wrong ID
      # will make the session script exit with a timeout.
      gpv_response = @gpv_response
      new_header = %{gpv_response.header | id: parsed.header.id}
      gpv_response = %{gpv_response | header: new_header}
      r=ACS.Session.process_message(@session_id, gpv_response) # Should be processed with no timeout
      assert r=={200,""}

      end_res=ACS.Session.Supervisor.end_session(@session_id)
      assert end_res == :ok
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

  test "Normal Session - with wrong ID in response" do
    acsex(ACS.Session.Script.Vendor) do
      Application.put_env(:acs_ex, :script_timeout, 1000, persistent: false)

      {:ok,pid} = ACS.Session.Supervisor.start_session(@session_id, @device_id, @inform, fn(session, _device_id, _message) ->
        import ACS.Session.Script.Vendor.Helpers
        # The script inserts a message in the queue.
        _r = getParameterValues(session, ["Device.Test."])
      end )
      assert is_pid(pid)

      assert Supervisor.count_children(:session_supervisor).active == 1

      # now pretend we send the inform into the session, this is what the plug does after creating it
      r=ACS.Session.process_message(@session_id, @inform)
      assert {200,@inform_response} == r

      {code,response}=ACS.Session.process_message(@session_id, @empty)
      assert code==200
      assert Regex.match?(@gpv_request,response)

      # another process_message for the response, but with the wrong ID
      # will make the session return a Fault, 8003
      {code,response}=ACS.Session.process_message(@session_id, @gpv_response)
      assert code == 200
      assert response == "" # because things we dont understand just means "END SESSION"
      end_res=ACS.Session.Supervisor.end_session(@session_id)
      assert end_res == :ok
      assert Supervisor.count_children(:session_supervisor).active == 0
      Application.delete_env(:acs_ex, :script_timeout)
    end
  end

  # Test what happens when a sessions gets input that is not
  # supposed to happen.
  test "Abnormal Session - double inform" do
    acsex(ACS.Session.Script.Vendor) do
      # Double process_message, so before we have a response to one message, what happens if
      # Another arrives?
      {:ok,pid} = ACS.Session.Supervisor.start_session(@session_id, @device_id, @inform)
      assert is_pid(pid)

      assert Supervisor.count_children(:session_supervisor).active == 1

      r=ACS.Session.process_message(@session_id, @inform)
      assert {200,@inform_response} == r


      r=ACS.Session.process_message(@session_id, @inform)
      assert {200,@inform_response} == r

      end_res=ACS.Session.Supervisor.end_session(@session_id)
      assert end_res == :ok
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

  # Tests if we can wait for the messages list to be filled in the session
  test "TransferComplete session" do
    acsex(ACS.Session.Script.Vendor) do
      {:ok,pid} = ACS.Session.Supervisor.start_session(@session_id, @device_id, @tc_inform, fn(_session,_did,_inform) ->
        Process.sleep(2000)
      end)
      assert is_pid(pid)
      assert Supervisor.count_children(:session_supervisor).active == 1

      r=ACS.Session.process_message(@session_id, @tc_inform)
      assert {200,@inform_response} == r

      # Start a process that sends a TransferComplete in 1 second

      # Now send a script message in, to retrieve the messagelist, that will get a noreply, and should get a reply when
      # the TransferComplete process has completed and sent "" into the session
      # send in a TransferComplete
      # Send in %{} - triggering a reply to the script message
      Task.start_link fn ->
        Process.sleep(1000)
        _response=ACS.Session.process_message(@session_id,@transfer_complete)
        ACS.Session.process_message(@session_id,%{})
      end

      messages=GenServer.call(pid, {:script_command, [:unscripted]})

      message=List.first(messages)
      entry=List.first(message.entries)
      assert entry.__struct__ == CWMP.Protocol.Messages.TransferComplete

      end_res=ACS.Session.Supervisor.end_session(@session_id)
      assert end_res == :ok
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

  # Testcase for handling sequence
  # 1. Inform
  # 2. TransferComplete
  # 3. scripted Download (before response to TransferComplete was sent)
  # (gave an exception cause the session state was off)
  test "TransferComplete #2" do
    acsex(ACS.Session.Script.Vendor) do
      {:ok,pid} = ACS.Session.Supervisor.start_session(@session_id, @device_id, @tc_inform, fn(session,_did,_inform) ->
        Process.sleep(1000)
        import ACS.Session.Script.Vendor.Helpers
        _r=download(session,%{commandkey: "FirmwareUpgrade", url: "http://exampl.com", filetype: "1 Firmware Upgrade Image", filesizei: 12345})
      end)
      assert is_pid(pid)
      assert Supervisor.count_children(:session_supervisor).active == 1

      r=ACS.Session.process_message(@session_id, @tc_inform)
      assert {200,@inform_response} == r

      # Send in the TransferComplete
      {code,_response}=ACS.Session.process_message(@session_id,@transfer_complete)
      # response to TransferComplere
      assert code == 200

      Process.sleep(2000)

      # How to assert that the Download was fired and handled correcyly?

      end_res=ACS.Session.Supervisor.end_session(@session_id)
      assert end_res == :ok
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

  # Testcase for at race condition occuring
  # when
  # 1. Inform
  # 2. scripted Download (before response to TransferComplete was sent)
  # 3. TransferComplete
  # (gave an exception cause the session state was off)
  test "TransferComplete #3" do
    acsex(ACS.Session.Script.Vendor) do
      {:ok,pid} = ACS.Session.Supervisor.start_session(@session_id, @device_id, @tc_inform, fn(session,_did,_inform) ->
        import ACS.Session.Script.Vendor.Helpers
        _r=download(session,%{commandkey: "FirmwareUpgrade", url: "http://example.com", filetype: "1 Firmware Upgrade Image", filesize: 12345})
      end)
      assert is_pid(pid)
      assert Supervisor.count_children(:session_supervisor).active == 1

      r=ACS.Session.process_message(@session_id, @tc_inform)
      assert {200,@inform_response} == r

      # Now wait for the scripted Download
      Process.sleep(1000)
      # Send in the TransferComplete
      {code,_response}=ACS.Session.process_message(@session_id,@transfer_complete)
      # response to TransferComplete
      assert code == 200

      parent = self
      # spawn this with delay
      child = spawn fn ->
        Process.sleep(1000)
        {code,response}=ACS.Session.process_message(@session_id, @empty)
        assert code==200
        {res,parsed} = CWMP.Protocol.Parser.parse(response)
        assert res == :ok
        assert is_list(parsed.entries)
        assert hd(parsed.entries).__struct__ == CWMP.Protocol.Messages.Download
        send parent, {self, parsed.header.id}
      end

      messages=GenServer.call(pid, {:script_command, [:unscripted]})
      assert messages == :error # an error here, because we already have one script element queued (Download)

      receive do
        {^child, download_header_id} ->
          # Send a download response into session
          downresp = @download_response
          downresp = %{downresp | header: %{downresp.header | id: download_header_id}}

          {code,response}=ACS.Session.process_message(@session_id,downresp)
          assert code == 200

          Task.start_link fn ->
            Process.sleep(1000)
            ACS.Session.process_message(@session_id,%{})
          end

          messages=GenServer.call(pid, {:script_command, [:unscripted]})
          assert is_list(messages)
          message=List.first(messages)
          entry=List.first(message.entries)
          assert entry.__struct__ == CWMP.Protocol.Messages.TransferComplete

          end_res=ACS.Session.Supervisor.end_session(@session_id)
          assert end_res == :ok
          assert Supervisor.count_children(:session_supervisor).active == 0
      end
    end
  end
end
