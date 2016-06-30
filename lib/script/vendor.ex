defmodule ACS.Session.Script.Vendor do
  require Logger
  import ACS.Session.Script.Vendor.Helpers
  #alias ACS.Session.Script.Vendor.Helpers

  @moduledoc """

  This is the main vendor specific logic module, and the one
  you want to write if you have stuff that needs to happen in
  you specific environment.

  """

  @doc """

    start is call when a session is initiated, from here all logic
    pertaining to the current CPE can be placed. 

    If you want to implement at start for each product_class,
    start(%{product_class: "something", ....}, message) is the way
    to do it.

  """
  def start(session,did,inform) do
    #reply = getParameterValues(session, ["Device.ManagementServer.URL"])
    #Logger.debug("Reply: #{inspect(reply)}")
  end

  # PRIVATE METHODS
  defp dequeue_external(serial) do
    deq=ACS.Queue.dequeue(serial)
    Logger.debug("dequeued=#{inspect(deq)}")
    case deq do
        {:ok,%{"dispatch" => dispatch, "source" => source, "args" => args}} -> {200,gen_request(dispatch,args,source,did)}
        junk -> Logger.debug("cant match dequeued event: #{inspect(junk)}")
                {200,""}
    end
  end
end
