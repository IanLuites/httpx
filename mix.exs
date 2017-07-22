defmodule Httpx.Mixfile do
  use Mix.Project

  def project do
    [
      app: :httpx,
      version: "0.0.1",
      elixir: "~> 1.4",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      package: package(),

      # Docs
      name: "HTTPX",
      source_url: "https://github.com/IanLuites/httpx",
      homepage_url: "https://github.com/IanLuites/httpx",
      docs: [
        main: "readme",
        extras: ["README.md"],
      ],
    ]
  end

  def package do
    [
      name: :analyze,
      maintainers: ["Ian Luites"],
      licenses: ["MIT"],
      files: [
        "lib/httpx", "lib/mix", "lib/httpx.ex", "mix.exs", "README*", "LICENSE*", # Elixir
      ],
      links: %{
        "GitHub" => "https://github.com/IanLuites/httpx",
      },
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:hackney, "1.8.0"}, # Specific version to prevent pool error.
      {:poison, "~> 3.1"},
    ]
  end
end
