# Solverl

Erlang/Elixir interface to [Minizinc](https://www.minizinc.org).
Disclaimer: The code has neither been extensively tested, nor used in production. Use on your own risk.

## Installation

You will need to install Minizinc. Please refer to https://www.minizinc.org/software.html for details.

Note: 
The code is known to run on macOS Catalina and Ubuntu 18.04 with Minizinc v2.4.3 only.

Note:
`minizinc` executable is expected to be in its default location, or in a folder in the $PATH `env` variable.
Otherwise, you can use `minizinc_executable` option (see [Solver Options](#solver-options)). 

The package can be installed by adding `solverl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:solverl, "~> 0.1.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/solverl](https://hexdocs.pm/solverl).

## Features
TODO

## Usage
```elixir
# Asynchronous solving.
# Creates a solver process. 
{:ok, solver_pid} = Minizinc.solve(model, data, opts)

# Synchronous solving.
# Starts the solver and gets the results (solutions and/or solver stats) once the solver finishes.
solver_results = Minizinc.solve_sync(model, data, opts)

```
, where: 
- ```model``` - [specification of the Minizinc model](#model-specification);
- ```data```  - [specification of data](#data-specification) passed to ```model```;
- ```opts``` - [solver options](#solver-options).

### Model specification

TODO

### Data specification

TODO

### Solver options

  - `solver`: Solver id supported by your Minizinc configuration. Default: "gecode".
  - `time_limit`: Time in msecs given to Minizinc to find a solution. Default: 30000.
  - `minizinc_executable`: Full path to Minizinc executable (you'd need it if executable cannot be located by your system).
  - `solution_handler`: Module or function that controls processing of solutions and/or metadata. Check out `Solution handlers` for more details. 
  - `extra_flags`: A string of command line flags supported by the solver. 
  

### Solution handlers

  Handling of solutions is done by the pluggable solution handler, specificied by ```solution_handler``` solver option. 
  The solution handler customizes the results and/or controls execution of the solver.

## Examples
 - [N-Queens](#n-queens)
 - [Sudoku](#sudoku)
 
### N-Queens

   The following code uses Minizinc model `mzn/nqueens.mzn` to solve [N-queens](https://developers.google.com/optimization/cp/queens) puzzle for N = 4:
   
   ```elixir
    MinizincSolver.solve("mzn/nqueens.mzn", %{n: 4}, [solution_handler: &NQueens.solution_handler/2])
   ```
   Output: 
   ``` 
17:16:53.073 [warn]  Command: /Applications/MiniZincIDE.app/Contents/Resources/minizinc --allow-multiple-assignments --output-mode json --output-time --output-objective --output-output-item -s -a  --solver org.gecode.gecode --time-limit 300000 /var/folders/rn/_39sx1c12ws1x5k66n_cjjh00000gn/T/tmp.vFlJER37.mzn /var/folders/rn/_39sx1c12ws1x5k66n_cjjh00000gn/T/tmp.rxTZq96j.dzn
{:ok, #PID<0.766.0>}
iex(75)> 
17:16:53.174 [info]  
. . ♕ .
♕ . . .
. . . ♕
. ♕ . .
-----------------------
 
17:16:53.174 [info]  
. ♕ . .
. . . ♕
♕ . . .
. . ♕ .
-----------------------
 
17:16:53.179 [info]  Solution status: all_solutions
 
17:16:53.179 [info]  Solver stats:
 %{failures: 4, initTime: 0.007719, nSolutions: 2, nodes: 11, peakDepth: 2, propagations: 163, propagators: 11, restarts: 0, solutions: 2, solveTime: 0.002778, variables: 12}

17:16:53.179 [debug] ** TERMINATE: :normal
 
   ```

### Sudoku

```elixir

## Asynchronously solve Sudoku puzzle, using the solution handler Sudoku.solution_handler/2:
## (the source code for Sudoku module is examples/sudoku.ex)

Sudoku.solve("85...24..72......9..4.........1.7..23.5...9...4...........8..7..17..........36.4.")
```
The output:
```
17:19:28.109 [info]  Sudoku puzzle:
 
17:19:28.109 [info]  
+-------+-------+-------+
| 8 5 . | . . 2 | 4 . . | 
| 7 2 . | . . . | . . 9 | 
| . . 4 | . . . | . . . | 
+-------+-------+-------+
| . . . | 1 . 7 | . . 2 | 
| 3 . 5 | . . . | 9 . . | 
| . 4 . | . . . | . . . | 
+-------+-------+-------+
| . . . | . 8 . | . 7 . | 
| . 1 7 | . . . | . . . | 
| . . . | . 3 6 | . 4 . | 
+-------+-------+-------+

 
17:19:28.154 [warn]  Command: /Applications/MiniZincIDE.app/Contents/Resources/minizinc --allow-multiple-assignments --output-mode json --output-time --output-objective --output-output-item -s -a  --solver org.gecode.gecode --time-limit 300000 /var/folders/rn/_39sx1c12ws1x5k66n_cjjh00000gn/T/tmp.uSF45sHN.mzn /var/folders/rn/_39sx1c12ws1x5k66n_cjjh00000gn/T/tmp.KjyUqmEa.dzn
{:ok, #PID<0.776.0>}
iex(79)> 
17:19:28.219 [info]  
+-------+-------+-------+
| 8 5 9 | 6 1 2 | 4 3 7 | 
| 7 2 3 | 8 5 4 | 1 6 9 | 
| 1 6 4 | 3 7 9 | 5 2 8 | 
+-------+-------+-------+
| 9 8 6 | 1 4 7 | 3 5 2 | 
| 3 7 5 | 2 6 8 | 9 1 4 | 
| 2 4 1 | 5 9 3 | 7 8 6 | 
+-------+-------+-------+
| 4 3 2 | 9 8 1 | 6 7 5 | 
| 6 1 7 | 4 2 5 | 8 9 3 | 
| 5 9 8 | 7 3 6 | 2 4 1 | 
+-------+-------+-------+

 
17:19:28.219 [info]  Solutions found: 1
 
17:19:28.224 [info]  Status: all_solutions
 
17:19:28.224 [info]  Solver statistics:
 %{failures: 11, initTime: 0.001401, nSolutions: 1, nodes: 23, peakDepth: 5, propagations: 685, propagators: 27, restarts: 0, solutions: 1, solveTime: 0.001104, variables: 147}

17:19:28.224 [debug] ** TERMINATE: :normal
```

## Under the hood
TODO

## Roadmap
TODO:
```
  Support LNS;
  Support Branch-and-Bound;
  Provide API for peeking into a state of Minizinc process, such as time since last solution,
  whether it's compiling or solving the model at the moment etc.
```  
