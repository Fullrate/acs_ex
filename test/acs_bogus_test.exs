defmodule ACSTestBogus do
  use ExUnit.Case
  import RequestSenders
  import TestHelpers
  doctest ACS

  test "bogus" do
    acsex(ACS.Session.Script.Vendor) do # the no-script
      {:ok,resp,_} = sendStr("bogus")
      # parse error yields, 400
      assert resp.body == "CWMP.Parser error: Malformed: Illegal character in prolog"
      assert resp.status_code == 400
    end
  end

  test "bogus xml" do
    acsex(ACS.Session.Script.Vendor) do # the no-script
      {:ok,resp,_} = sendStr("<xml version=\"1.0\"><some_half_xml>asdasd</")
      # parse error yields, 400
      assert resp.body == "CWMP.Parser error: Malformed: Unexpected end of data"
      assert resp.status_code == 400
    end
  end
end
