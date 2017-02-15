defmodule ACSFilterTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers
  doctest ACS

  test "filter message" do
    acsex(ACS.Test.Session.Filtered) do # the no-script
      assert Supervisor.count_children(:session_supervisor).active == 0
      {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
      assert resp.status_code == 404
      assert resp.body == "Not found"
      assert cookie == ["session=; path=/; HttpOnly"]
    end
  end

end

defmodule ACS.Test.Session.Filtered do
  use ACS.SessionScript

  def session_filter(_device_id, _inform) do
    {:reject, "Not found"}
  end

end
