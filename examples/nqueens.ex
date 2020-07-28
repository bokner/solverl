defmodule NQueens do
  @moduledoc """
    Example: N-queens solver.
  """

  require Logger

  @nqueens_model "mzn/nqueens.mzn"
  @queen_symbol "\u2655"

  # N queens puzzle
  # Async solving
  def solve(n, opts \\ [solution_handler: &solution_handler/2]) do
    Minizinc.solve(@nqueens_model, %{n: n}, opts)
  end

  def solve_sync(n, opts \\ [solution_handler: NQueens.SyncHandler]) do
    Minizinc.solve_sync(@nqueens_model, %{n: n}, opts)
  end

  @doc false
  ## Printing solver stats
  def solution_handler(:summary,
          %{solver_stats: stats, status: status} = _summary
      )
    do
    Logger.info "Solution status: #{status}"
    Logger.info "Solver stats:\n #{inspect stats}"
  end

  ## Printing solutions
  def solution_handler(:solution, %{
              index: _count,
              data: data} = _results) do
    Logger.info print_board(data["q"]) <> "\n-----------------------"
  end

  @doc false
  ## quuens[i] = j <=> row i has a queen in position j.
  def print_board(queens) do
    n = length(queens)
    "\n" <> Enum.join(
    for i <- 1..n do
      Enum.join(
      for j <- 1..n do
        if Enum.at(queens, i - 1) == j, do: @queen_symbol, else: "."
      end, " ")
    end, "\n")
  end

end



defmodule NQueens.SyncHandler do
  @behaviour MinizincHandler
  @moduledoc false
  require Logger
  import NQueens

  @doc false
  def handle_solution(%{data: data} = solution)  do
    Logger.info print_board(data["q"]) <> "\n-----------------------"
    {:solution, solution}
  end

  @doc false
  def handle_summary(%{solver_stats: solver_stats} = summary) do
    Logger.info "Solver stats:\n #{inspect solver_stats}"
    Logger.info "Model method: #{MinizincModel.model_method(summary)}"
    MinizincHandler.DefaultSync.handle_summary(summary)
  end

  @doc false
  def handle_minizinc_error(error) do
    Logger.info "Minizinc error: #{error}"
    {:error, error}
  end

end
