ExUnit.start()

defmodule TestHelpers do
  defmacro acsex(module, do: body) do
    quote do
      # Allow for teardown...
      Process.sleep(100)

      spec =
        {unquote(module),
         acs_port: Application.fetch_env!(:acs_ex, :acs_port),
         acs_ip: Application.fetch_env!(:acs_ex, :acs_ip),
         acs_ipv6: Application.fetch_env!(:acs_ex, :acs_ip6)}

      {:ok, acs_ex_pid} = ACS.start_link(spec)

      unquote(body)
      Supervisor.stop(acs_ex_pid)
    end
  end

  def generate_datetime(
        {{day, month, year}, {hour, minute, second}},
        timezone \\ "Etc/UTC",
        zone_abbr \\ "UTC",
        utc_offset \\ 0
      ) do
    %DateTime{
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: second,
      utc_offset: utc_offset,
      microsecond: {0, 0},
      time_zone: timezone,
      zone_abbr: zone_abbr,
      std_offset: 0
    }
  end
end

defmodule PathHelpers do
  def fixture_path do
    Path.expand("fixtures", __DIR__)
  end

  def fixture_path(file_path) do
    Path.join(fixture_path(), file_path)
  end
end

defmodule RequestSenders do
  # sends a POST request, and eats the response and returns it
  def sendFile(file, sessioncookie \\ []) do
    {:ok, data} = File.read(file)
    sendStr(data, sessioncookie)
  end

  defp get_random_port do
    port = Application.fetch_env!(:acs_ex, :acs_port)

    cond do
      is_list(port) ->
        hd(Enum.take_random(port, 1))

      true ->
        port
    end
  end

  # sends a POST request, and eats the response and returns it
  def sendStr(str, sessioncookie \\ []) do
    port = get_random_port()

    resp =
      case sessioncookie do
        [] ->
          HTTPoison.post("http://localhost:#{port}/", str, %{"Content-type" => "text/xml"})

        [s] ->
          HTTPoison.post("http://localhost:#{port}/", str, %{"Content-type" => "text/xml"},
            hackney: [cookie: [s]]
          )
      end

    case resp do
      {:ok, r} ->
        sessioncookie =
          case List.keyfind(r.headers, "set-cookie", 0) do
            {"set-cookie", s} -> [s]
            _ -> []
          end

        {:ok, r, sessioncookie}

      {:error, r} ->
        {:error, r, []}
    end
  end

  def readFixture!(file) do
    {:ok, data} = File.read(file)
    String.trim_trailing(data, "\n")
  end

  def compare_envelopes(env1, env2) do
    # first line of envelope contains the attributes which have random order out of the component
    lines1 = String.split(env1, "\n", trim: true)
    lines2 = String.split(env2, "\n", trim: true)

    case {lines1, lines2} do
      {[first_line1 | rest1], [first_line2 | rest2]} ->
        trimmed_first_line1 = String.replace(first_line1, ~r/[<>]/, "")
        trimmed_first_line2 = String.replace(first_line2, ~r/[<>]/, "")

        words1 = String.split(trimmed_first_line1, " ") |> Enum.sort()
        words2 = String.split(trimmed_first_line2, " ") |> Enum.sort()

        if words1 == words2 and rest1 == rest2 do
          {:ok, :match}
        else
          {:error, :no_match}
        end

      _ ->
        {:error, :invalid_input}
    end
  end
end
