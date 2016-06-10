defmodule ACS_EX.Mixfile do
  use Mix.Project

  def project do
    [app: :acs_ex,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     dialyzer: [plt_apps: [:cwmp_ex, :plug, :poison, :timex, :kafka_ex]]]
  end

  def application do
    [applications: [:logger, :cowboy, :plug, :kafka_ex, :httpoison,
      :tzdata],
     included_applications: [:cwmp_ex, :tools, :timex, :poison],
     mod: {acs_ex, []}]
  end

  defp deps do
    [{:cowboy, "~> 1.0"},
     {:plug, "~> 1.1"},
     {:timex, "~> 1.0"},
     {:cwmp_ex, git: "/Volumes/Work/git/cwmp_ex"},
     {:kafka_ex, "~> 0.5.0"},
     {:httpoison, "~> 0.8.0"},
     {:poison, "~> 2.0"}]
  end
end
