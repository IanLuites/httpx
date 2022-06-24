defmodule Httpx.Mixfile do
  use Mix.Project

  def project do
    [
      app: :httpx,
      description: "Simple Elixir library with HTTP[S] helpers.",
      version: "0.1.6",
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
      dialyzer: [
        ignore_warnings: ".dialyzer",
        plt_add_deps: true,
        plt_add_apps: [:certifi, :public_key]
      ],

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
      {:hackney, "~> 1.17"},
      {:jason, "~> 1.2"},
      {:brotli, "~> 0.2", optional: true},

      # Dev / Test
      {:heimdallr, ">= 0.0.3", only: [:dev, :test]}
    ]
  end
end
