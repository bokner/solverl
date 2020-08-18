defmodule MinizincInstance do
  @moduledoc false

  def new(model, data \\ [], solver_opts \\ [], server_opts \\ []) do
    %{
      model: model,
      data: data,
      solver_opts: solver_opts,
      server_opts: server_opts
    }
  end

  def run(instance) do
    run(instance, true)
  end

  def run(
        %{
          model: model,
          data: data,
          solver_opts: solver_opts,
          server_opts: server_opts
        } = instance,
        sync
      ) when is_map(instance) and is_boolean(sync) do

    if sync do
      MinizincSolver.solve_sync(model, data, solver_opts, server_opts)
    else
      MinizincSolver.solve(model, data, solver_opts, server_opts)
    end
  end
end
