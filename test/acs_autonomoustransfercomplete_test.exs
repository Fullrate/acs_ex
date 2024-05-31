defmodule ACSAutonomousTransferCompleteTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers
  doctest ACS

  test "plain AutonomousTransferComplete" do
    acsex(ACS.Session.Script.Vendor) do # the no-script
      assert Supervisor.count_children(:session_supervisor).active == 0
      {:ok,resp,cookie} = sendFile(fixture_path("informs/transfercomplete1"))
      assert compare_envelopes(resp.body, readFixture!(fixture_path("informs/plain1_response"))) == {:ok, :match}
      assert resp.status_code == 200
      {:ok,resp,cookie} = sendFile(fixture_path("acs/autonomoustransfercomplete1"), cookie)
      assert resp.body == readFixture!(fixture_path("acs/autonomoustransfercomplete1_response"))
      assert resp.status_code == 200
      {:ok,resp,_} = sendStr("",cookie)
      assert resp.body == ""
      assert resp.status_code == 204
    end
  end

end
