defmodule MinizincHandler do
  @moduledoc """
    Behaviour, default implementations and helpers for solution handlers.
  """

  @callback handle_solution(solution :: map()) ::
              :break | {:break, any()} | :skip | any()

  @callback handle_summary(summary :: map()) :: any()

  @callback handle_minizinc_error(mzn_error :: map()) :: any()

  @callback on_compiled(compilation_info :: map()) :: any()

  ## Provide stubs for MinizincHandler behaviour
  defmacro __using__(_) do
    quote do
      @behaviour MinizincHandler
      def handle_solution(solution) do
        MinizincHandler.Default.handle_solution(solution)
      end

      def handle_summary(summary) do
        MinizincHandler.Default.handle_summary(summary)
      end

      def handle_minizinc_error(error) do
        MinizincHandler.Default.handle_minizinc_error(error)
      end

      def on_compiled(compilation_info) do
        MinizincHandler.Default.on_compiled(compilation_info)
      end

      defoverridable MinizincHandler
    end
  end

  @doc false

  # Helpers to call handler callbacks uniformly.

  def handle_solver_event(:solution, solution, solution_handler) do
    handle_solution(solution, solution_handler)
  end

  def handle_solver_event(:summary, summary, solution_handler) do
    handle_summary(summary, solution_handler)
  end

  def handle_solver_event(:minizinc_error, error, solution_handler) do
    handle_minizinc_error(error, solution_handler)
  end

  def handle_solver_event(:compiled, compilation_info, solution_handler) do
    on_compiled(compilation_info, solution_handler)
  end

  # The solution handler can be either a function, or a callback module.
  #
  @doc false

  def handle_solution(solution, solution_handler) when is_function(solution_handler) do
    solution_handler.(:solution, solution)
  end

  def handle_solution(solution, solution_handler) do
    solution_handler.handle_solution(solution)
  end

  @doc false
  def handle_summary(summary, solution_handler) when is_function(solution_handler) do
    solution_handler.(:summary, summary)
  end

  def handle_summary(summary, solution_handler) do
    solution_handler.handle_summary(summary)
  end

  @doc false
  def handle_minizinc_error(error, solution_handler) when is_function(solution_handler) do
    solution_handler.(:minizinc_error, error)
  end

  def handle_minizinc_error(error, solution_handler) do
    solution_handler.handle_minizinc_error(error)
  end

  def on_compiled(compilation_info, solution_handler) when is_function(solution_handler) do
    solution_handler.(:compiled, compilation_info)
  end

  def on_compiled(compilation_info, solution_handler) do
    solution_handler.on_compiled(compilation_info)
  end
end

defmodule MinizincHandler.Default do
  @moduledoc false

  require Logger
  use MinizincHandler

  def handle_solution(solution) do
    solution
  end

  def handle_summary(summary) do
    summary
  end

  def handle_minizinc_error(error) do
    error
  end

  def on_compiled(compilation_info) do
    compilation_info
  end
end
