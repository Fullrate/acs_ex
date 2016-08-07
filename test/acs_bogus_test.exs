defmodule ACSTestBogus do
  use ExUnit.Case
  import PathHelpers
  import RequestSenders
  import TestHelpers
  doctest ACS

  test "bogus xml" do
    acsex(ACS.Session.Script.Vendor) do # the no-script
      {:ok,resp,_} = sendStr("bogus")
      # parse error yields, 400
      assert resp.body == "Error handling request"
      assert resp.status_code == 400
    end
  end
end
