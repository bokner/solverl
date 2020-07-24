defmodule MinizincHandler do
  @moduledoc """
    Behaviour, default implementations and helpers for solution handlers.
  """


  @callback handle_solution(MinizincResults.solution())
            :: {:ok, term} | :stop | {:stop, any()}

  @callback handle_summary(summary :: MinizincResults.summary()
              )
            :: :ok | {:ok, any()}

  @callback handle_minizinc_error(mzn_error :: MinizincResults.minizinc_error()) :: any

  ## Provide stubs for MinizincHandler behaviour
  defmacro __using__(_) do
    quote do
      @behaviour MinizincHandler
      def handle_solution(_solution) do :ok end
      def handle_summary(_summary) do :ok end
      def handle_minizinc_error(_error) do :ok end
      defoverridable MinizincHandler
    end
  end

  @doc """
    Helper to call handler callbacks uniformly.
    The solution handler can be either a function, or a callback module.
  """
  ## Solution handler as a function
  def handle_solver_event(event, results, solution_handler) when is_function(solution_handler) do
    solution_handler.(event, results)
  end

  ## Solution handler as a callback
  def handle_solver_event(:solution, results, solution_handler) do
    solution_handler.handle_solution(MinizincResults.solution(results))
  end

  def handle_solver_event(:summary, results, solution_handler) do
    solution_handler.handle_summary(MinizincResults.summary(results))
  end

  def handle_solver_event(:minizinc_error, results, solution_handler) do
    solution_handler.handle_minizinc_error(MinizincResults.minizinc_error(results))
  end


end

defmodule MinizincHandler.DefaultAsync do
  require Logger
  use MinizincHandler

  def handle_solution(solution) do
    Logger.info "Solution: #{inspect solution}"
  end

  def handle_summary(summary) do
    Logger.info "Summary: #{inspect summary}"
  end

  def handle_minizinc_error(error) do
    Logger.info "Minizinc error: #{inspect error}"
  end
end

defmodule MinizincHandler.DefaultSync do
  require Logger
  require Record
  use MinizincHandler

  def handle_solution(solution)  do
    {:solution, solution}
  end

  def handle_summary(summary)  do
    {:summary, summary}
  end

  def handle_minizinc_error(error)  do
    {:error, error}
  end
end

