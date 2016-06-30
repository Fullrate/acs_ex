defmodule ACS.Mixfile do
  use Mix.Project

  def project do
    [app: :acs_ex,
     version: "0.0.2",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     dialyzer: [plt_apps: [:cwmp_ex, :plug, :poison, :timex]]]
  end

  def application do
    [applications: [:logger, :cowboy, :plug, :httpoison, :redix,
      :tzdata, :poolboy, :gproc],
     included_applications: [:cwmp_ex, :tools, :timex, :poison],
     mod: {ACS, []}]
  end

  defp deps do
    [{:cowboy, "~> 1.0"},
     {:plug, "~> 1.1"},
     {:cwmp_ex, github: "Fullrate/cwmp_ex"},
     {:kafka_ex, "~> 0.5.0"},
     {:httpoison, "~> 0.8.0"},
     {:poison, "~> 2.0"},
     {:poolboy, github: "devinus/poolboy" },
     {:redix, "~> 0.3.6"},
     {:mock, "~> 0.1.1", only: :test},
     {:logger_file_backend, github: "onkel-dirtus/logger_file_backend"},
     {:gproc, "~> 0.5.0"},
     {:cryptex, "~> 0.0.1"}]
  end
end
