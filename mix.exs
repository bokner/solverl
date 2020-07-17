defmodule Solverl.MixProject do
  use Mix.Project

  def project do
    [
      app: :solverl,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: ["lib", "examples"]
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
      {:distillery, "~> 2.1"}
    ]
  end
end
