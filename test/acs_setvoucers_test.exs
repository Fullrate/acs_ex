defmodule ACSSetVouchersTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers

  @response ~s|<SOAP-ENV:Envelope xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="urn:dslforum-org:cwmp-1-4" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
\t<SOAP-ENV:Header>
\t\t<cwmp:ID SOAP-ENV:mustUnderstand="1">~s</cwmp:ID>
\t</SOAP-ENV:Header>
\t<SOAP-ENV:Body>
\t\t<cwmp:SetVouchersResponse/>
\t</SOAP-ENV:Body>
</SOAP-ENV:Envelope>|

  test "queue SetVouchers" do
    acsex(ACS.Test.Sessions.SetVouchers) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert compare_envelopes(resp.body, readFixture!(fixture_path("informs/plain1_response"))) == {:ok, :match}
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendStr("",cookie) # This should cause a Download request
      assert resp.status_code == 200

      {pres,parsed}=CWMP.Protocol.Parser.parse(resp.body)
      if pres != :ok do
        IO.inspect("SetVouchers #{pres} #{resp.body}")
      end
      assert pres == :ok

      # header id is now in: parsed.header.id

      # assert values are what we expect them to be.
      assert hd(parsed.entries).voucherlist == ["PFNpZ25hdHVyZSB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC8wOS94bWxkc2lnIyI+CiAgPFNpZ25lZEluZm8+CiAgICA8Q2Fub25pY2FsaXphdGlvbk1ldGhvZCBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnL1RSLzIwMDEvUkVDLXhtbC1jMTRuLTIwMDEwMzE1Ii8+CiAgICA8U2lnbmF0dXJlTWV0aG9kIEFsZ29yaXRobT0iaHR0cDovL3d3dy53My5vcmcvMjAwMC8wOS94bWxkc2lnI2RzYS1zaGExIi8+CiAgICA8UmVmZXJlbmNlIFVSST0iI29wdGlvbjAiPgogICAgICA8VHJhbnNmb3Jtcz4KICAgICAgICA8VHJhbnNmb3JtIEFsZ29yaXRobT0iaHR0cDovL3d3dy53My5vcmcvVFIvMjAwMS9SRUMteG1sLWMxNG4tMjAwMTAzMTUiPjwvVHJhbnNmb3JtPgogICAgICA8L1RyYW5zZm9ybXM+CiAgICAgIDxEaWdlc3RNZXRob2QgQWxnb3JpdGhtPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwLzA5L3htbGRzaWcjc2hhMSI+PC9EaWdlc3RNZXRob2Q+CiAgICAgIDxEaWdlc3RWYWx1ZT5UVXVTcXIydXRMdFFNNXRZMkRCMWpMM25WMDA9PC9EaWdlc3RWYWx1ZT4KICAgIDwvUmVmZXJlbmNlPgogICAgPFJlZmVyZW5jZSBVUkk9IiNvcHRpb24xIj4KICAgICAgPFRyYW5zZm9ybXM+CiAgICAgICAgPFRyYW5zZm9ybSBBbGdvcml0aG09Imh0dHA6Ly93d3cudzMub3JnL1RSLzIwMDEvUkVDLXhtbC1jMTRuLTIwMDEwMzE1Ij48L1RyYW5zZm9ybT4KICAgICAgPC9UcmFuc2Zvcm1zPgogICAgICA8RGlnZXN0TWV0aG9kIEFsZ29yaXRobT0iaHR0cDovL3d3dy53My5vcmcvMjAwMC8wOS94bWxkc2lnI3NoYTEiPjwvRGlnZXN0TWV0aG9kPgogICAgICA8RGlnZXN0VmFsdWU+L1lYMUMvRTZ6TmYwK3c0bEc2Nk5lWEdPUUIwPTwvRGlnZXN0VmFsdWU+CiAgICA8L1JlZmVyZW5jZT4KICA8L1NpZ25lZEluZm8+CiAgPFNpZ25hdHVyZVZhbHVlPktBTWZxT1NubUdINTJxUlZHTE5GRUVNNFBQa1JTbU1VR3IyRDhFM3Z3d1cyODBlMUJuNXB3UT09PC9TaWduYXR1cmVWYWx1ZT4KICA8S2V5SW5mbz4KICAgIDxLZXlWYWx1ZT4KICAgICAgPERTQUtleVZhbHVlPgogICAgICAgIDxQPi9YOVRnUjExRWlsUzMwcWNMdXprNS9ZUnQxSTg3MFFBd3g0L2dMWlJKbWxGWFVBaVVmdFpQWTFZK3IvRjlib3c5cwp1YlZXelhnVHVBSFRSdjhtWmd0MnVaVUtXa241L29CSHNRSXNKUHU2blgvcmZHRy9nN1YrZkdxS1lWRHdUN2cvYlQKeFI3REFqVlVFMW9Xa1RMMmRmT3VLMkhYS3UveUlnTVpuZEZJQWNjPTwvUD4KICAgICAgICA8UT5sMkJRanhVakM4eXlrcm1Db3V1RUMvQllIUFU9PC9RPgogICAgICAgIDxHPjkrR2doZGFiUGQ3THZLdGNOcmhYdVhtVXI3djZPdXFDK1ZkTUN6MEhnbWRSV1ZlT3V0UlpUK1p4QnhDQmdMUkpGbgpFajZFd29GaE8zendreWpNaW00VHdXZW90VWZJMG80S091SGl1enBuV1JicU4vQy9vaE5XTHgrMko2QVNRN3pLVHgKdnFoUmtJbW9nOS9oV3VXZkJwS0xabDZBZTFVbFpBRk1PLzdQU1NvPTwvRz4KICAgICAgICA8WT5UQkFTQS9takxJOGJjMktNN3U5WDZuSEh2am1QZ1p0VEJocjEvRnpzMkFrZFlDWU13eXkrditPWFU3dTVlMThKdUsKRzcvdW9sVmhqWE5TbjZaZ09iRit3dU1veVAvT1VtTmJTa2ROMWFSWFhIUFJzVzJDY0czdmpmVitDc2cvTFAzemZECnhEa0ltc0M4THVLWGh0L2c0K25rc0EvM2ljUlFYV2FnUUpVOXBVUT08L1k+CiAgICAgIDwvRFNBS2V5VmFsdWU+CiAgICA8L0tleVZhbHVlPgogICAgPFg1MDlEYXRhPgogICAgICA8WDUwOUlzc3VlclNlcmlhbD4KICAgICAgICA8WDUwOUlzc3Vlck5hbWU+RU1BSUxBRERSRVNTPW5hbWVAZXhhbXBsZS5jb20sQ049RXhhbXBsZSxPVT1DTVMsTz1FeGFtcGxlLEw9U2FuMjBKb3NlLCBTVD1DYWxpZm9ybmlhLEM9VVM8L1g1MDlJc3N1ZXJOYW1lPgogICAgICAgIDxYNTA5U2VyaWFsTnVtYmVyPjQ8L1g1MDlTZXJpYWxOdW1iZXI+CiAgICAgIDwvWDUwOUlzc3VlclNlcmlhbD4KICAgICAgPFg1MDlTdWJqZWN0TmFtZT5DTj1lbmcuYmJhLmNlcnRzLmV4YW1wbGUuY29tLE9VPUNNUyxPPUV4YW1wbGUsTD1TYW4yMEpvc2UsU1Q9Q0EsQz1VUzwvWDUwOVN1YmplY3ROYW1lPgogICAgICA8WDUwOUNlcnRpZmljYXRlPk1JSUVVakNDQTd1Z0F3SUJBZ0lCQkRBTkJna3Foa2lHOXcwQkFRVUZBRENCaERFTE1Ba0dBMVVFQmhNQ1ZWTXhFekFSQmdOVkJBZ1QKQ2tOaGJHbG1iM0p1YVdFeEVUQVBCZ05WQkFjVENGTmhiaUJLYjNObE1RNHdEQVlEVlFRS0V3VXlWMmx5WlRFTU1Bb0dBMVVFQ3hNRApRMDFUTVE0d0RBWURWUVFERXdVeVYybHlaVEVmTUIwR0NTcUdTSWIzRFFFSkFSWVFaV0p5YjNkdVFESjNhWEpsTG1OdmJUQWVGdzB3Ck1qQTVNRFV5TURVNE1UWmFGdzB4TWpBNU1ESXlNRFU0TVRaYU1HMHhDekFKQmdOVkJBWVRBbFZUTVFzd0NRWURWUVFJRXdKRFFURVIKTUE4R0ExVUVCeE1JVTJGdUlFcHZjMlV4RGpBTUJnTlZCQW9UQlRKWGFYSmxNUXd3Q2dZRFZRUUxFd05EVFZNeElEQWVCZ05WQkFNVApGMlZ1Wnk1aVltRXVZMlZ5ZEhNdU1uZHBjbVV1WTI5dE1JSUJ0ekNDQVN3R0J5cUdTTTQ0QkFFd2dnRWZBb0dCQVAxL1U0RWRkUklwClV0OUtuQzdzNU9mMkViZFNQTzlFQU1NZVA0QzJVU1pwUlYxQUlsSDdXVDJOV1BxL3hmVzZNUGJMbTFWczE0RTdnQjAwYi9KbVlMZHIKbVZDbHBKK2Y2QVI3RUNMQ1Q3dXAxLzYzeGh2NE8xZm54cWltRlE4RSs0UDIwOFVld3dJMVZCTmFGcEV5OW5YenJpdGgxeXJ2OGlJRApHWjNSU0FISEFoVUFsMkJRanhVakM4eXlrcm1Db3V1RUMvQllIUFVDZ1lFQTkrR2doZGFiUGQ3THZLdGNOcmhYdVhtVXI3djZPdXFDCitWZE1DejBIZ21kUldWZU91dFJaVCtaeEJ4Q0JnTFJKRm5FajZFd29GaE8zendreWpNaW00VHdXZW90VWZJMG80S091SGl1enBuV1IKYnFOL0Mvb2hOV0x4KzJKNkFTUTd6S1R4dnFoUmtJbW9nOS9oV3VXZkJwS0xabDZBZTFVbFpBRk1PLzdQU1NvRGdZUUFBb0dBVEJBUwpBL21qTEk4YmMyS003dTlYNm5ISHZqbVBnWnRUQmhyMS9GenMyQWtkWUNZTXd5eSt2K09YVTd1NWUxOEp1S0c3L3VvbFZoalhOU242ClpnT2JGK3d1TW95UC9PVW1OYlNrZE4xYVJYWEhQUnNXMkNjRzN2amZWK0NzZy9MUDN6ZkR4RGtJbXNDOEx1S1hodC9nNCtua3NBLzMKaWNSUVhXYWdRSlU5cFVTamdkQXdnYzB3SFFZRFZSME9CQllFRk1UbC9lYmRITGphRW9TUzFQY0xDQWRGWDMycU1JR2JCZ05WSFNNRQpnWk13Z1pDaGdZcWtnWWN3Z1lReEN6QUpCZ05WQkFZVEFsVlRNUk13RVFZRFZRUUlFd3BEWVd4cFptOXlibWxoTVJFd0R3WURWUVFICkV3aFRZVzRnU205elpURU9NQXdHQTFVRUNoTUZNbGRwY21VeEREQUtCZ05WQkFzVEEwTk5VekVPTUF3R0ExVUVBeE1GTWxkcGNtVXgKSHpBZEJna3Foa2lHOXcwQkNRRVdFR1ZpY205M2JrQXlkMmx5WlM1amIyMkNBUUF3RGdZRFZSMFBBUUgvQkFRREFnZUFNQTBHQ1NxRwpTSWIzRFFFQkJRVUFBNEdCQUYxUEdBYnl2QTBwKzZvN25YZkYzanpBZG9IZGFaaDU1QzhzT1E5SjYySUY4RDFqbDZKeFI3cGpjQ3AyCmlZbVdrd1FNbmNHZnErWDh4UDdCSXFudERtSWxZWHVEVGxYYnl4WHN1NmxuVDduQ2JKd013bExPeEZ3TitBeHk3Qk0zTmtBRkU1TWIKYWFvSld0bUQxUXJ2Y0FGZkRoTGVCVCt0SVJ1ZUs3UHE5TERTPC9YNTA5Q2VydGlmaWNhdGU+CiAgICAgIDxYNTA5Q2VydGlmaWNhdGU+TUlJQ2VUQ0NBZUlDQVFBd0RRWUpLb1pJaHZjTkFRRUVCUUF3Z1lReEN6QUpCZ05WQkFZVEFsVlRNUk13RVFZRFZRUUlFd3BEWVd4cApabTl5Ym1saE1SRXdEd1lEVlFRSEV3aFRZVzRnU205elpURU9NQXdHQTFVRUNoTUZNbGRwY21VeEREQUtCZ05WQkFzVEEwTk5VekVPCk1Bd0dBMVVFQXhNRk1sZHBjbVV4SHpBZEJna3Foa2lHOXcwQkNRRVdFR1ZpY205M2JrQXlkMmx5WlM1amIyMHdIaGNOTURFd056TXgKTURNd05qUTVXaGNOTURjd01USXhNRE13TmpRNVdqQ0JoREVMTUFrR0ExVUVCaE1DVlZNeEV6QVJCZ05WQkFnVENrTmhiR2xtYjNKdQphV0V4RVRBUEJnTlZCQWNUQ0ZOaGJpQktiM05sTVE0d0RBWURWUVFLRXdVeVYybHlaVEVNTUFvR0ExVUVDeE1EUTAxVE1RNHdEQVlEClZRUURFd1V5VjJseVpURWZNQjBHQ1NxR1NJYjNEUUVKQVJZUVpXSnliM2R1UURKM2FYSmxMbU52YlRDQm56QU5CZ2txaGtpRzl3MEIKQVFFRkFBT0JqUUF3Z1lrQ2dZRUExSVNKYkw2aTBKLzZTQm9ldDNhQThma2k4czdwYi9RVVp1ZVdqKzBZS29EYVFXaDRNVUNUMEswNgpOLzBaMmNMTVZnOEp5ZXpFcGRuaDNsVk0vTmk1b3cyTXN0NGRwZGNjUVFFSG91cXdOVVdJQkZVMTk2L0xQUnlMam9NMk5lSVhTS01qCkFkUHd2Y2VueG1xZVZCci9aVW1yNEpRcGRTSTJBWkp1SHZDSWpVc0NBd0VBQVRBTkJna3Foa2lHOXcwQkFRUUZBQU9CZ1FCYTNDQ1gKZ2E5TDBxckdXeHBOajMxMkF6K3RZejhicEVwMmUycEFWckpIZFcvQ0owdVJsRTM0MW9Ua2hmWUZhNUN1dWllRjdKY3dmMUIzK2NHbwpKckxXcWVLcXNObnJibU1GQy85aG5yTGxnWktFS2kwUE9hR1NGUy9Qdzlub2RHV0ZaQ2lhUW1lRytKNkNXZUFTaUZNZHdnUkd2RVNXCmF4Znp6SUtpWHNYd2tBPT08L1g1MDlDZXJ0aWZpY2F0ZT4KICAgIDwvWDUwOURhdGE+CiAgPC9LZXlJbmZvPgogIDxkc2lnOk9iamVjdCBJZD0iI29wdGlvbjAiIHhtbG5zPSIiIHhtbG5zOmRzaWc9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvMDkveG1sZHNpZyMiPgogICAgPE9wdGlvbj4KICAgICAgPFZTZXJpYWxOdW0+OTg3NjU0MzIxPC9WU2VyaWFsTnVtPgogICAgICA8RGV2aWNlSWQ+CiAgICAgICAgPE1hbnVmYWN0dXJlcj5FeGFtcGxlPC9NYW51ZmFjdHVyZXI+CiAgICAgICAgPE9VST4wMTIzNDU8L09VST4KICAgICAgICA8UHJvZHVjdENsYXNzPkdhdGV3YXk8L1Byb2R1Y3RDbGFzcz4KICAgICAgICA8U2VyaWFsTnVtYmVyPjEyMzQ1Njc4OTwvU2VyaWFsTnVtYmVyPgogICAgICA8L0RldmljZUlkPgogICAgICA8T3B0aW9uSWRlbnQ+Rmlyc3Qgb3B0aW9uIGhlcmU8L09wdGlvbklkZW50PgogICAgICA8T3B0aW9uRGVzYz5GaXJzdCBvcHRpb24gZGVzY3JpcHRpb248L09wdGlvbkRlc2M+CiAgICAgIDxTdGFydERhdGU+MjAxNS0wMS0xOVQyMzowODoyNFo8L1N0YXJ0RGF0ZT4KICAgICAgPER1cmF0aW9uPjI4MDwvRHVyYXRpb24+CiAgICAgIDxEdXJhdGlvblVuaXRzPkRheXM8L0R1cmF0aW9uVW5pdHM+CiAgICAgIDxNb2RlPkVuYWJsZVdpdGhFeHBpcmF0aW9uPC9Nb2RlPgogICAgPC9PcHRpb24+CiAgPC9kc2lnOk9iamVjdD4KICA8ZHNpZzpPYmplY3QgSWQ9IiNvcHRpb24xIiB4bWxucz0iIiB4bWxuczpkc2lnPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwLzA5L3htbGRzaWcjIj4KICAgIDxPcHRpb24+CiAgICAgIDxWU2VyaWFsTnVtPjk4NzY1NDMyMTwvVlNlcmlhbE51bT4KICAgICAgPERldmljZUlkPgogICAgICAgIDxNYW51ZmFjdHVyZXI+RXhhbXBsZTwvTWFudWZhY3R1cmVyPgogICAgICAgIDxPVUk+MDEyMzQ1PC9PVUk+CiAgICAgICAgPFByb2R1Y3RDbGFzcz5HYXRld2F5PC9Qcm9kdWN0Q2xhc3M+CiAgICAgICAgPFNlcmlhbE51bWJlcj4xMjM0NTY3ODk8L1NlcmlhbE51bWJlcj4KICAgICAgPC9EZXZpY2VJZD4KICAgICAgPE9wdGlvbklkZW50PkZpcnN0IG9wdGlvbiBoZXJlPC9PcHRpb25JZGVudD4KICAgICAgPE9wdGlvbkRlc2M+Rmlyc3Qgb3B0aW9uIGRlc2NyaXB0aW9uPC9PcHRpb25EZXNjPgogICAgICA8U3RhcnREYXRlPjIwMTUtMDEtMTlUMjM6MDg6MjRaPC9TdGFydERhdGU+CiAgICAgIDxEdXJhdGlvbj4yODA8L0R1cmF0aW9uPgogICAgICA8RHVyYXRpb25Vbml0cz5EYXlzPC9EdXJhdGlvblVuaXRzPgogICAgICA8TW9kZT5FbmFibGVXaXRoRXhwaXJhdGlvbjwvTW9kZT4KICAgIDwvT3B0aW9uPgogIDwvZHNpZzpPYmplY3Q+CjwvU2lnbmF0dXJlPg=="]

      assert Supervisor.count_children(:session_supervisor).active == 1

      # Send a Response to end it. Should return "", end session by sending "" back
      response=to_string(:io_lib.format(@response,[parsed.header.id]))
      {:ok,resp,_} = sendStr(response,cookie)
      assert resp.body == ""
      assert resp.status_code == 204
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

  test "queue SetVouchers with bogus parameters" do
    acsex(ACS.Test.Sessions.SetVouchersBogusParams) do
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert compare_envelopes(resp.body, readFixture!(fixture_path("informs/plain1_response"))) == {:ok, :match}
      assert resp.status_code == 200

      {:ok,resp,_cookie} = sendStr("",cookie) # This should cause the Bogus Download request
      assert resp.status_code == 204
      assert resp.body == "" # since the Download was bogus, we expect the session to just end.
      assert Supervisor.count_children(:session_supervisor).active == 0
    end
  end

end # of test module

defmodule ACS.Test.Sessions.SetVouchers do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers
  import TestHelpers

  def session_start(session, _deviceid, _inform) do
    _r=setVouchers(session, [
      %{signature_value: "KAMfqOSnmGH52qRVGLNFEEM4PPkRSmMUGr2D8E3vwwW280e1Bn5pwQ==",
        key_info: %{
          key_value: %{
            dsa_p: "/X9TgR11EilS30qcLuzk5/YRt1I870QAwx4/gLZRJmlFXUAiUftZPY1Y+r/F9bow9s
ubVWzXgTuAHTRv8mZgt2uZUKWkn5/oBHsQIsJPu6nX/rfGG/g7V+fGqKYVDwT7g/bT
xR7DAjVUE1oWkTL2dfOuK2HXKu/yIgMZndFIAcc=",
            dsa_q: "l2BQjxUjC8yykrmCouuEC/BYHPU=",
            dsa_g: "9+GghdabPd7LvKtcNrhXuXmUr7v6OuqC+VdMCz0HgmdRWVeOutRZT+ZxBxCBgLRJFn
Ej6EwoFhO3zwkyjMim4TwWeotUfI0o4KOuHiuzpnWRbqN/C/ohNWLx+2J6ASQ7zKTx
vqhRkImog9/hWuWfBpKLZl6Ae1UlZAFMO/7PSSo=",
            dsa_y: "TBASA/mjLI8bc2KM7u9X6nHHvjmPgZtTBhr1/Fzs2AkdYCYMwyy+v+OXU7u5e18JuK
G7/uolVhjXNSn6ZgObF+wuMoyP/OUmNbSkdN1aRXXHPRsW2CcG3vjfV+Csg/LP3zfD
xDkImsC8LuKXht/g4+nksA/3icRQXWagQJU9pUQ="
          },
          x509_data: %{
            issuer_serial: %{
              issuer_name: "EMAILADDRESS=name@example.com,CN=Example,OU=CMS,O=Example,L=San\20Jose, ST=California,C=US",
              serial_number: 4
            },
            subject_name: "CN=eng.bba.certs.example.com,OU=CMS,O=Example,L=San\20Jose,ST=CA,C=US",
            certificates: ["MIIEUjCCA7ugAwIBAgIBBDANBgkqhkiG9w0BAQUFADCBhDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
CkNhbGlmb3JuaWExETAPBgNVBAcTCFNhbiBKb3NlMQ4wDAYDVQQKEwUyV2lyZTEMMAoGA1UECxMD
Q01TMQ4wDAYDVQQDEwUyV2lyZTEfMB0GCSqGSIb3DQEJARYQZWJyb3duQDJ3aXJlLmNvbTAeFw0w
MjA5MDUyMDU4MTZaFw0xMjA5MDIyMDU4MTZaMG0xCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJDQTER
MA8GA1UEBxMIU2FuIEpvc2UxDjAMBgNVBAoTBTJXaXJlMQwwCgYDVQQLEwNDTVMxIDAeBgNVBAMT
F2VuZy5iYmEuY2VydHMuMndpcmUuY29tMIIBtzCCASwGByqGSM44BAEwggEfAoGBAP1/U4EddRIp
Ut9KnC7s5Of2EbdSPO9EAMMeP4C2USZpRV1AIlH7WT2NWPq/xfW6MPbLm1Vs14E7gB00b/JmYLdr
mVClpJ+f6AR7ECLCT7up1/63xhv4O1fnxqimFQ8E+4P208UewwI1VBNaFpEy9nXzrith1yrv8iID
GZ3RSAHHAhUAl2BQjxUjC8yykrmCouuEC/BYHPUCgYEA9+GghdabPd7LvKtcNrhXuXmUr7v6OuqC
+VdMCz0HgmdRWVeOutRZT+ZxBxCBgLRJFnEj6EwoFhO3zwkyjMim4TwWeotUfI0o4KOuHiuzpnWR
bqN/C/ohNWLx+2J6ASQ7zKTxvqhRkImog9/hWuWfBpKLZl6Ae1UlZAFMO/7PSSoDgYQAAoGATBAS
A/mjLI8bc2KM7u9X6nHHvjmPgZtTBhr1/Fzs2AkdYCYMwyy+v+OXU7u5e18JuKG7/uolVhjXNSn6
ZgObF+wuMoyP/OUmNbSkdN1aRXXHPRsW2CcG3vjfV+Csg/LP3zfDxDkImsC8LuKXht/g4+nksA/3
icRQXWagQJU9pUSjgdAwgc0wHQYDVR0OBBYEFMTl/ebdHLjaEoSS1PcLCAdFX32qMIGbBgNVHSME
gZMwgZChgYqkgYcwgYQxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpDYWxpZm9ybmlhMREwDwYDVQQH
EwhTYW4gSm9zZTEOMAwGA1UEChMFMldpcmUxDDAKBgNVBAsTA0NNUzEOMAwGA1UEAxMFMldpcmUx
HzAdBgkqhkiG9w0BCQEWEGVicm93bkAyd2lyZS5jb22CAQAwDgYDVR0PAQH/BAQDAgeAMA0GCSqG
SIb3DQEBBQUAA4GBAF1PGAbyvA0p+6o7nXfF3jzAdoHdaZh55C8sOQ9J62IF8D1jl6JxR7pjcCp2
iYmWkwQMncGfq+X8xP7BIqntDmIlYXuDTlXbyxXsu6lnT7nCbJwMwlLOxFwN+Axy7BM3NkAFE5Mb
aaoJWtmD1QrvcAFfDhLeBT+tIRueK7Pq9LDS", "MIICeTCCAeICAQAwDQYJKoZIhvcNAQEEBQAwgYQxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpDYWxp
Zm9ybmlhMREwDwYDVQQHEwhTYW4gSm9zZTEOMAwGA1UEChMFMldpcmUxDDAKBgNVBAsTA0NNUzEO
MAwGA1UEAxMFMldpcmUxHzAdBgkqhkiG9w0BCQEWEGVicm93bkAyd2lyZS5jb20wHhcNMDEwNzMx
MDMwNjQ5WhcNMDcwMTIxMDMwNjQ5WjCBhDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCkNhbGlmb3Ju
aWExETAPBgNVBAcTCFNhbiBKb3NlMQ4wDAYDVQQKEwUyV2lyZTEMMAoGA1UECxMDQ01TMQ4wDAYD
VQQDEwUyV2lyZTEfMB0GCSqGSIb3DQEJARYQZWJyb3duQDJ3aXJlLmNvbTCBnzANBgkqhkiG9w0B
AQEFAAOBjQAwgYkCgYEA1ISJbL6i0J/6SBoet3aA8fki8s7pb/QUZueWj+0YKoDaQWh4MUCT0K06
N/0Z2cLMVg8JyezEpdnh3lVM/Ni5ow2Mst4dpdccQQEHouqwNUWIBFU196/LPRyLjoM2NeIXSKMj
AdPwvcenxmqeVBr/ZUmr4JQpdSI2AZJuHvCIjUsCAwEAATANBgkqhkiG9w0BAQQFAAOBgQBa3CCX
ga9L0qrGWxpNj312Az+tYz8bpEp2e2pAVrJHdW/CJ0uRlE341oTkhfYFa5CuuieF7Jcwf1B3+cGo
JrLWqeKqsNnrbmMFC/9hnrLlgZKEKi0POaGSFS/Pw9nodGWFZCiaQmeG+J6CWeASiFMdwgRGvESW
axfzzIKiXsXwkA=="]
          }
        },
        options: [
          %{v_serial_num: "987654321",
            deviceid: %{
                manufacturer: "Example",
                oui: "012345",
                product_class: "Gateway",
                serial_number: "123456789"},
              option_ident: "First option here",
              option_desc: "First option description",
              start_date: generate_datetime({{19,1,2015},{23,8,24}}),
              duration: 280,
              duration_units: "Days",
              mode: "EnableWithExpiration",
              sha1_digest: "TUuSqr2utLtQM5tY2DB1jL3nV00="
            },
            %{
              v_serial_num: "987654321",
              deviceid: %{
                manufacturer: "Example",
                oui: "012345",
                product_class: "Gateway",
                serial_number: "123456789"},
              option_ident: "First option here",
              option_desc: "First option description",
              start_date: generate_datetime({{19,1,2015},{23,8,24}}),
              duration: 280,
              duration_units: "Days",
              mode: "EnableWithExpiration",
              sha1_digest: "/YX1C/E6zNf0+w4lG66NeXGOQB0="
            }
          ]
        }
    ])
  end

end

defmodule ACS.Test.Sessions.SetVouchersBogusParams do
  use ACS.SessionScript
  import ACS.Session.Script.Vendor.Helpers

  def session_start(session, _deviceid, _inform) do
    _r=setVouchers(session, %{
      furl: "bogus"})
  end

end
