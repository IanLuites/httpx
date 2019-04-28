defmodule Httpx.Mixfile do
  use Mix.Project

  def project do
    [
      app: :httpx,
      description: "Simple Elixir library with HTTP[S] helpers.",
      version: "0.0.16",
      elixir: "~> 1.4",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),

      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [ignore_warnings: ".dialyzer", plt_add_deps: true],

      # Docs
      name: "HTTPX",
      source_url: "https://github.com/IanLuites/httpx",
      homepage_url: "https://github.com/IanLuites/httpx",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  def package do
    [
      name: :httpx,
      maintainers: ["Ian Luites"],
      licenses: ["MIT"],
      files: [
        # Elixir
        "lib/httpx",
        "lib/httpx.ex",
        "mix.exs",
        "README*",
        "LICENSE*"
      ],
      links: %{
        "GitHub" => "https://github.com/IanLuites/httpx"
      }
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:hackney, "~> 1.15"},
      {:jason, "~> 1.1"},

      # Dev / Test
      {:analyze, ">= 0.0.13", optional: true, only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", optional: true, only: :dev, runtime: false}
    ]
  end
end
