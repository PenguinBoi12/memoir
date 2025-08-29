defmodule Memoir.MixProject do
  use Mix.Project

  @source_url "https://github.com/PenguinBoi12/memoir"
  @version "0.1.0"

  def project do
    [
      app: :memoir,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:excoveralls, "~> 0.18", only: :test},
      {:meck, "~> 1.0.0", only: :test},
      {:cachex, "~> 4.1.1", optional: true, only: [:dev, :test]}
    ]
  end

  defp description do
    """
    Memoir is a lightweight, Rails-inspired caching library for Elixir with a pluggable
    backend architecture.
    """
  end

  defp package do
    [
      maintainers: ["Simon Roy"],
      licenses: ["GPL-3.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "Memoir",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/memoir",
      source_url: @source_url,
      extras: ["README.md", "LICENSE"]
    ]
  end
end