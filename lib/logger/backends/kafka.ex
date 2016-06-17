defmodule Logger.Backends.Kafka do
  use GenEvent

  def init(_) do
    if user = Process.whereis(:user) do
      Process.group_leader(self(), user)
      {:ok, configure([])}
    else
      {:error, :ignore}
    end
  end

  def handle_call({:configure, options}, _state) do
    {:ok, :ok, configure(options)}
  end

  def handle_event({_level, gl, _event}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level} = state) do
    if is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt do
      log_event(level, msg, ts, md, state)
    end
    {:ok, state}
  end

  ## Helpers

  defp configure(options) do
    kafka = Keyword.merge(Application.get_env(:logger, :kafka, []), options)
    Application.put_env(:logger, :kafka, kafka)

    format = kafka
      |> Keyword.get(:format)
      |> Logger.Formatter.compile

    level    = Keyword.get(kafka, :level)
    metadata = Keyword.get(kafka, :metadata, [])
    %{format: format, metadata: metadata, level: level}
  end

  defp log_event(level, msg, ts, md, %{format: format, metadata: metadata}) do
    key=Map.take(msg,"ip")
    fmsg=Logger.Formatter.format(format, level, Poison.encode!(Map.put(msg,:user,:user)), ts, Dict.take(md, metadata))
    KafkaEx.produce(Application.fetch_env!(:logger, :kafka, :topic), 0, fmsg, key: key)
  end
end
