defmodule ACS.Mixfile do
  use Mix.Project

  def project do
    [
      app: :acs_ex,
      version: "0.3.18",
      elixir: "~> 1.13",

      # Docs
      name: "acs_ex",
      source_url: "https://github.com/Fullrate/acs_ex",
      docs: [
        main: "acs_ex",
        extras: ["README.md"]
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: "An ACS server based on the cwmp_ex module",
      package: package(),
      deps: deps(),
      dialyzer: [plt_apps: [:cwmp_ex, :plug, :poison, :timex]]
    ]
  end

  def application do
    []
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
      {:plug_cowboy, "~> 2.5.2"},
      {:uuid, "~> 1.1.8"},
      {:cwmp_ex, "~> 0.2.6"},
      {:httpoison, "~> 1.8.0"},
      {:poison, "~> 5.0.0"},
      {:poolboy, "~> 1.5.2"},
      {:gproc, "~> 0.9.0"},
      {:mock, "~> 0.3.7", only: :test},
      {:prometheus_ex, "~> 3.0.5"},
      {:ex_doc, "~> 0.28.3", only: :dev, runtime: false}
    ]
  end
end
