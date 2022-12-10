defmodule Solverl.MixProject do
  use Mix.Project

  def project do
    [
      app: :solverl,
      version: "1.0.17",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: ["lib", "examples"],
      deps: deps(),
      description: description(),
      docs: docs(),
      package: package()
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
      {:jason, "~> 1.2"},
      {:distance, "~> 0.2.2"},
      {:erlexec, "~> 2.0"},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Elixir/Erlang interface to MiniZinc (https://www.minizinc.org/)."
  end

  defp docs do
    [
      main: "readme",
      formatter_opts: [gfm: true],
      extras: [
        "README.md"
      ]
    ]
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib examples test src .formatter.exs mix.exs README* ),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/bokner/solverl"}
    ]
  end
end
