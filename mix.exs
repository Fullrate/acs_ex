defmodule ACS.Mixfile do
  use Mix.Project

  def project do
    [app: :acs_ex,
     version: "0.3.17",
     elixir: "~> 1.8",

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
      {:plug_cowboy, "~> 2.0"},
      {:uuid, "~> 1.1.8"},
      {:cwmp_ex, "~> 0.2.5"},
      {:httpoison, "~> 1.3.1"},
      {:poison, "~> 4.0.1"},
      {:poolboy, "~> 1.5.1"},
      {:gproc, "~> 0.8.0"},
      {:mock, "~> 0.3.2", only: :test},
      {:prometheus_ex, "~> 3.0.3"},
      {:ex_doc, "~> 0.19.1", only: :dev, runtime: false}
    ]
  end
end
