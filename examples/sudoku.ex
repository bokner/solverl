defmodule Sudoku do
  @moduledoc false

  # Example: Sudoku solver.
  # Sudoku puzzle is a string with elements of the puzzle in row-major order,
  # where a blank entry is represented by "."

  require Logger

  import MinizincUtils

  @sample_sudoku_1_solution  "85...24..72......9..4.........1.7..23.5...9...4...........8..7..17..........36.4."
  @sample_sudoku_5_solutions "8..6..9.5.............2.31...7318.6.24.....73...........279.1..5...8..36..3......"

  @sudoku_model resource_file("mzn/sudoku.mzn")

  @doc """
    Solve asynchronously using Sudoku.Handler as a solution handler.
  """
  def solve(puzzle, solver_opts \\ [solution_handler: Sudoku.Handler])

  def solve(puzzle, solver_opts) when is_binary(puzzle) do
    solve(sudoku_string_to_grid(puzzle), solver_opts)
  end

  def solve(puzzle, solver_opts) when is_list(puzzle) do
    Logger.info "Sudoku puzzle:"
    Logger.info print_grid(puzzle)
    {:ok, _pid} = MinizincSolver.solve(
      @sudoku_model,
      %{"S": 3, start: puzzle},
      solver_opts
    )
  end

  @doc """
   ```elixir
   # Solve synchronously.
   # Example (prints all solutions):

   Enum.each(Sudoku.solve_sync(
      "8..6..9.5.............2.31...7318.6.24.....73...........279.1..5...8..36..3......"),
      fn ({:solution, sol}) -> Logger.info Sudoku.print_grid(sol["puzzle"])
         (_) -> :ok
      end)
  ```
  """
  def solve_sync(puzzle, solver_opts \\ [solution_handler: Sudoku.Handler])

  def solve_sync(puzzle, solver_opts) when is_binary(puzzle) do
    solve_sync(sudoku_string_to_grid(puzzle), solver_opts)
  end

  def solve_sync(puzzle, solver_opts) when is_list(puzzle) do
    Logger.info "Sudoku puzzle (solved synchronously)"
    Logger.info print_grid(puzzle)
    {:ok, res} = MinizincSolver.solve_sync(
      @sudoku_model,
      %{"S": 3, start: puzzle},
      solver_opts
    )
    res
  end

  @doc false
  def sudoku_string_to_grid(sudoku_str) do
    str0 = String.replace(sudoku_str, ".", "0")
    for i <- 1..9 do
       for j <- 1..9 do
         String.to_integer(String.at(str0, (i - 1) * 9 + (j - 1)))
       end
      end
  end

  @doc false
  def print_solution(data, count) do
    Logger.info "#{print_grid(data["puzzle"])}"
    #Logger.info "Grid: #{data["puzzle"]}"
    Logger.info "Solutions found: #{count}"
  end

  @doc false
  def print_grid(grid) do
    gridline = "+-------+-------+-------+\n"
    gridcol = "| "

    [
      "\n" |
      for i <- 0..8 do
        [(if rem(i, 3) == 0, do: gridline, else: "")] ++
        (for j <- 0..8 do
           "#{if rem(j, 3) == 0, do: gridcol, else: ""}" <>
           "#{print_cell(Enum.at(Enum.at(grid, i), j))} "
         end) ++ ["#{gridcol}\n"]
      end
    ] ++ [gridline]
  end

  defp print_cell(0) do
    "."
  end

  defp print_cell(cell) do
    cell
  end

  @doc false
  def sudoku_samples() do
    [
      @sample_sudoku_1_solution,
      @sample_sudoku_5_solutions
    ]
  end

end


defmodule Sudoku.Handler do
  @moduledoc false

  require Logger
  use MinizincHandler

  ## Handle no more than 3 solutions, print the final one.
  @doc false
  def handle_solution(%{index: count, data: data} = solution) do
    Sudoku.print_solution(data, count)
    MinizincHandler.Default.handle_solution(solution)
  end

  @doc false
  def handle_summary(summary) do
    Logger.info "Status: #{summary[:status]}"
    Logger.info "Solver statistics:\n #{inspect summary[:solver_stats]}"
    MinizincHandler.Default.handle_summary(summary)
  end

  @doc false
  def handle_minizinc_error(error) do
    Logger.info "Minizinc error: #{error}"
    MinizincHandler.Default.handle_minizinc_error(error)
  end
end
