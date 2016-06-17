defmodule ACS.Log do
  @moduledoc """
  Performs logging and state-store updates about ACS requests.
  """

  @doc """
  Logs an unsuccessful ACS request.

  Usually this only happens if the request is invalid.
  """
  def acs_log_error(conn, inform, error) do
    entry = base_log(conn, inform)
    entry = Map.merge(entry, %{"msg" => "ERROR: #{error}"})
    write_log(entry)
  end

  defp extract_params(inform, field) do
    alias CWMP.Protocol.Messages.ParameterValueStruct
    inform.parameters
    |> Enum.filter(fn %ParameterValueStruct{name: name} ->
      case name do
        "InternetGatewayDevice." <> ^field -> true
        "Device." <> ^field -> true
        _ -> false
      end
    end)
  end

  defp extract_first_value(inform, field) do
    case extract_params(inform, field) |> Enum.map(fn p -> p.value end) do
      [p | _] -> p
      _ -> nil
    end
  end

  defp parse_provcode(provcode) when is_binary(provcode) do
    case Integer.parse(provcode) do
      {val, _} -> val
      _ -> nil
    end
  end
  defp parse_provcode(_), do: nil

  defp unknown?(nil), do: "Unknown"
  defp unknown?(""), do: "Unknown"
  defp unknown?(v), do: v

  @doc """
  Logs a successful Inform ACS request.

  The inform as well as information about the ACS server used and the customer
  provisioning code are written to the Kafka logtopic.
  """
  def acs_log_inform(conn, inform) do
    entry = base_log(conn, inform)
    entry = Map.merge(entry, %{"msg" => "Inform"})
    write_log(entry)
  end

  def write_event(entry) do
    case Application.fetch_env!(:acs_ex, :logmode) do
      "kafka" -> _ = KafkaEx.produce(Application.fetch_env!(:acs_ex, :eventtopic), 0, Poison.encode!(entry), key: entry["ip"])
      "file" -> # write to logfile
          log_to_eventfile(Poison.encode!(entry))
    end
    :ok # For now, always return OK here
  end

  def write_log(entry) do
    _ = KafkaEx.produce(Application.fetch_env!(:acs_ex, :logtopic), 0, Poison.encode!(entry), key: entry["ip"])
    :ok # For now, always return OK here
  end

  def log_to_eventfile(event) do
    file=Application.fetch_env!(:acs_ex, :eventfile)
    File.write(file,event,[mode: :append])
  end

  defp base_log(conn, inform) do
    provcode = extract_first_value(inform, "DeviceInfo.ProvisioningCode")
    firmware = extract_first_value(inform, "DeviceInfo.SoftwareVersion")

    %{
      "ip"           => "#{:inet_parse.ntoa(conn.remote_ip)}",
      "ts"           => Timex.DateTime.now(:local) |> Timex.format!("{ISO}"),
      "host"         => conn.host,
      "Manufacturer" => unknown?(inform.device_id.manufacturer),
      "ProductClass" => unknown?(inform.device_id.product_class),
      "SerialNumber" => unknown?(inform.device_id.serial_number),
      "firmware"     => unknown?(firmware),
      "provcode"     => unknown?(provcode),
      "events"       => Enum.map(inform.events, fn e -> e.code end),
    }
  end
end
