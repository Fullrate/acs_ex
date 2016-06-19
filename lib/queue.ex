defmodule ACS.Queue do

  def enqueue(serial, command, args, source) do
    encoded=Poison.encode!(%{dispatch: command, args: args, source: source})
    ACS.RedixPool.command(~w(RPUSH #{serial} #{encoded}))
  end

  def dequeue(serial) do
    case ACS.RedixPool.command(~w(LPOP #{serial})) do
      {:ok, json} when not is_nil(json) -> Poison.decode(json)
      {:ok, json} when is_nil(json) -> {:error,"Nothing in queue"}
      {:error, err} -> {:error, err}
    end
  end

  def dequeue_all(serial,acc,fun) do
    case ACS.RedixPool.command(~w(LPOP #{serial})) do
      {:ok, json} when not is_nil(json) -> case Poison.decode(json) do
                                             {:ok,s} -> fun.(s,acc)
                                                        dequeue_all(serial,acc ++ [s],fun)
                                             {:error,err} -> {:error,err}
                                           end
      _ -> {:ok,acc}
    end
  end

  def dequeue_all(serial,fun) do
    dequeue_all(serial,[],fun)
  end

  def dequeue_all(serial) do
    dequeue_all(serial,fn(x,acc) -> x end)
  end
end
