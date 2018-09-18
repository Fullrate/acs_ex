defmodule ACS.Mixfile do
  use Mix.Project

  def project do
    [app: :acs_ex,
     version: "0.3.11",
     elixir: "~> 1.7",

     # Docs
     name: "acs_ex",
     source_url: "https://github.com/Fullrate/acs_ex",
     docs: [
       main: "acs_ex",
       extras: ["README.md"]
     ],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: "An ACS server based on the cwmp_ex module",
     package: package(),
     deps: deps(),
     dialyzer: [plt_apps: [:cwmp_ex, :plug, :poison, :timex]]]
  end

  def application do
    [applications: [:cowboy, :plug, :httpoison,
      :poolboy, :gproc, :crypto, :prometheus_ex],
     included_applications: [:cwmp_ex, :tools]]
  end

  defp package do
    [
      maintainers: ["Jesper Dalberg"],
      licenses: ["Artistic"],
      links: %{"GitHub" => "https://github.com/Fullrate/acs_ex"}
    ]
  end

  defp deps do
    [
      {:cowboy, "~> 1.0"},
      {:uuid, "~> 1.1"},
      {:plug, "~> 1.1"},
      {:cwmp_ex, "~> 0.2.3"},
      {:httpoison, "~> 0.11.1"},
      {:poison, "~> 2.0"},
      {:poolboy, "~> 1.5.1"},
      {:gproc, "~> 0.6.1"},
      {:mock, "~> 0.1.1", only: :test},
      {:prometheus_ex, "~> 3.0.2"},
      {:ex_doc, "~> 0.19.0", only: :dev, runtime: false}
    ]
  end
end
