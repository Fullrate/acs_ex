defmodule ACSTest do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  doctest ACS

  test "bogus xml" do
    {:ok,resp,_} = sendStr("bogus")
    # parse error yields, 400
    assert resp.body == "Error handling request" && resp.status_code == 400
  end

  test "plain InformResponse" do
    {:ok,resp,cookie} = sendFile(fixture_path("informs/plain1"))
    assert resp.body == readFixture!(fixture_path("informs/plain1_response"))
    assert resp.status_code == 200
    {:ok,resp,_} = sendStr("",cookie)
    assert resp.body == ""
    assert resp.status_code == 200
  end

end
