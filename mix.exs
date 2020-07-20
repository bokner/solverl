defmodule Solverl.MixProject do
  use Mix.Project

  def project do
    [
      app: :solverl,
      version: "0.1.1",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: ["lib", "examples"],
      deps: deps(),
      description: description(),
      package: package(),

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
      {:rexbug, ">= 1.0.0"},
      {:jason, "~> 1.2"},
      {:distillery, "~> 2.1"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Elixir/Erlang interface to Minizinc (https://www.minizinc.org/)."
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib examples test .formatter.exs mix.exs README* ),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/bokner/solverl"}
    ]
  end
end
