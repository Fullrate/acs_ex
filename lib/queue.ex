defmodule ACS.Queue do

  def enqueue(serial, command, args, source) do
    encoded=Poison.encode!(%{dispatch: command, args: args, source: source})
    ACS.RedixPool.command(~w(RPUSH #{serial} #{encoded}))
  end

  def dequeue(serial) do
    case ACS.RedixPool.command(~w(LPOP #{serial})) do
      {:ok, json} -> Poison.decode(json)
      {:error, err} -> {:error, err}
    end
  end

end
