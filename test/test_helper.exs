ExUnit.start

defmodule PathHelpers do
  def fixture_path do
    Path.expand("fixtures", __DIR__)
  end

  def fixture_path(file_path) do
    Path.join fixture_path, file_path
  end
end

defmodule RequestSenders do
  # sends a POST request, and eats the response and returns it
  def sendFile(file, sessioncookie \\ []) do
    { :ok, data } = File.read(file)
    sendStr(data, sessioncookie)
  end

  # sends a POST request, and eats the response and returns it
  def sendStr(str, sessioncookie \\ []) do
    port=Application.fetch_env!(:acs_ex, :acs_port);
    case sessioncookie do
      [] -> HTTPoison.post("http://localhost:#{port}/", str, %{"Content-type" => "text/xml"})
      [s] -> HTTPoison.post("http://localhost:#{port}/", str, %{"Content-type" => "text/xml"}, [hackney: [cookie: [s]]])
    end
  end
end
