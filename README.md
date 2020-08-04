# Solverl

Erlang/Elixir interface to [Minizinc](https://www.minizinc.org).

Inspired by [Minizinc Python](https://minizinc-python.readthedocs.io/en/0.3.0/index.html).

**Disclaimer**: This project is in its very early stages, and has not been used in production, nor extensively tested. Use at your own risk.

- [Installation](#installation)
- [Features](#features)
- [Usage](#usage)
  - [Model specification](#model-specification)
  - [Data specification](#data-specification)
  - [Support for Minizinc data types](#support-for-minizinc-data-types)
  - [Configuring the solver](#solver-options)
  - [Solution handlers: customizing results and controlling execution](#solution-handlers)    
- [Examples](#model-solving-examples)
- [Erlang interface](#erlang-interface)
- [Roadmap](#roadmap)
- [Credits](#credits)

## Installation

You will need to install Minizinc. Please refer to https://www.minizinc.org/software.html for details.

###### **Note**:
 
The code was only tested on macOS Catalina and Ubuntu 18.04 with Minizinc v2.4.3.

###### **Note**:

`minizinc` executable is expected to be in its default location, or in a folder in the $PATH `env` variable.
Otherwise, you can use the `minizinc_executable` option (see [Solver Options](#solver-options)). 


The package can be installed by adding `solverl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:solverl, "~> 0.1.5"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/solverl](https://hexdocs.pm/solverl).

## Features

- Synchronous and asynchronous solving
- Pluggable solution handlers 
- Support for basic Minizinc types, arrays, sets and enums


## Usage

[MinizincSolver](MinizincSolver.html) module provides functions both for synchronous and asynchronous solving. 

```elixir
# Asynchronous solving.
# Creates a solver process. 
{:ok, solver_pid} = MinizincSolver.solve(model, data, opts)

# Synchronous solving.
# Starts the solver and gets the results (solutions and/or solver stats) once the solver finishes.
solver_results = MinizincSolver.solve_sync(model, data, opts)

```
, where 
- ```model``` - [specification of Minizinc model](#model-specification);
- ```data```  - [specification of data](#data-specification) passed to ```model```;
- ```opts``` - [solver options](#solver-options).

### Model specification

Model could be either:

- a string, in which case it represents a path for a file containing Minizinc model. 

    **Example:** "mzn/sudoku.mzn"
    
- or, a tuple {:text, `model_text`}. 
    
    **Example (model as a multiline string):** 
    ```elixir
    """
    array [1..5] of var 1..n: x;            
    include "alldifferent.mzn";            
    constraint alldifferent(x);
    """
    ```
- or a (mixed) list of the above. The code will build a model by concatenating bodies of
    model files and model texts suffixed with EOL (\n).  
    
    **Example:**
    ```elixir 
    ["mzn/test1.mzn", {:text, "constraint y[1] + y[2] <= 0;"}]
    ```
            
### Data specification

Data could be either:

- a string, in which case it represents a path for a Minizinc data file. 

    **Example:** "mzn/sudoku.dzn"

- a map, in which case map keys/value represent model `par` names/values.

    **Example:**
     ```elixir
     %{n: 5, f: 3.44} 
     ```  
       
- or a (mixed) list of the above. The code will build a data file by mapping elements of the list
    to bodies of data files and/or data maps, serialized as described in [Support for Minizinc data types](#support-for-minizinc-data-types),
     then concatenating the elements of the list, suffixed with EOL (\n). 
    
    **Example:**
    ```elixir
    ["mzn/test_data1.dzn", "mzn/test_data2.dzn", %{x: 2, y: -3, z: true}]
    ```
### Support for Minizinc data types

- #### Arrays

    Minizinc `array` type corresponds to (nested) [List](https://hexdocs.pm/elixir/List.html).
    The code determines dimensions of the array based on its nested structure.
    Each level of nested list has to contain elements of the same length, or the exception 
    `{:irregular_array, array}` will be thrown.
    6 levels of nesting are currently supported, in line with Minizinc.
    
    By default, the indices of the dimensions are 1-based.
    
    **Example:**
    ```elixir
    arr2d = [       
      [0, 1, 0, 1, 0],
      [0, 1, 0, 1, 0],
      [0, 1, 0, 1, 0],
      [0, 1, 0, 1, 0],
      [0, 1, 0, 1, 0]
    ]
    MinizincData.elixir_to_dzn(arr2d)
    ```
    Output:
    ```
    "array2d(1..5,1..5,[0,1,0,1,0,0,1,0,1,0,0,1,0,1,0,0,1,0,1,0,0,1,0,1,0])"
    ```
     
     You can explicitly specify bases for each dimension:
     ```elixir
     # Let 1st dimension be 0-based, 2nd dimension be 1-based
     MinizincData.elixir_to_dzn({[0, 1], arr2d})
     ```
     Output:
     ```
     "array2d(0..4,1..5,[0,1,0,1,0,0,1,0,1,0,0,1,0,1,0,0,1,0,1,0,0,1,0,1,0])" 
     ```
      
- #### Sets

    Minizinc `set` type corresponds to [MapSet](https://hexdocs.pm/elixir/MapSet.html).
    
    Example:
    ```elixir
    MinizincData.elixir_to_dzn(MapSet.new([2, 1, 6]))
    ```
    Output:
    ```elixir
    "{1,2,6}"
    ```
- #### Enums

     Minizinc `enum` type corresponds to [Tuple](https://hexdocs.pm/elixir/Tuple.html).
     Tuple elements have to be either of strings, charlists or atoms.
     
     Example 1 (using strings, atoms and charlists for enum entries):
     ```elixir
     MinizincData.elixir_to_dzn({"blue", :BLACK, 'GREEN'})
     ```
     Output:
     ```elixir
     "{blue, BLACK, GREEN}"
     ```
  Example 2 (solving for `enum` variable):
  ```elixir
    enum_model = 
  """
    enum COLOR;
    var COLOR: color;
    constraint color = max(COLOR);
  """
  results = MinizincSolver.solve_sync({:text, enum_model}, %{'COLOR': {"White", "Black", "Red", "BLue", "Green"}})   
  results[:summary][:last_solution][:data]["color"]   
  ```
  Output:
  ```elixir
    "Green" 
  ```
     

### Solver options

  - `solver`: Solver id supported by your Minizinc configuration. 
 
    Default: "gecode".
  - `time_limit`: Time in msecs given to Minizinc to find a solution. 
  
    Default: 300000 (5 mins). Use `[time_limit: nil]` for unlimited time.
  - `minizinc_executable`: Full path to Minizinc executable (you'd need it if `minizinc` executable cannot be located by your system).
  - `solution_handler`: Module or function that controls processing of solutions and/or metadata. 
  
    Default: MinizincHandler.DefaultAsync.
  
    Check out [Solution handlers](#solution-handlers) for more details. 
  - `extra_flags`: A string of command line flags supported by the solver. 
  
  Example:
  ```elixir
  ## Solve "mzn/nqueens.mzn" for n = 4, using Gecode solver,
  ## time limit of 1 sec, NQueens.SyncHandler as a solution handler.
  ## Extra flags: -O4 --verbose-compilation  
  MinizincSolver.solve_sync("mzn/nqueens.mzn", %{n: 4}, 
    [solver: "gecode", 
     time_limit: 1000, 
     solution_handler: NQueens.SyncHandler, 
     extra_flags: "-O4 --verbose-compilation"])
  ```
  

### Solution handlers

  **Solution handler** is a pluggable code created by the user in order to customize
  processing of solutions and metadata produced by **MinizincSolver.solve/3** and **MinizincSolver.solve_sync/3**.
  
  **Solution handler** is specified by `solution_handler` [option](#solver-options).
  
  Solution handler is either 
  - a *function*, or
  - a *module* that implements [MinizincHandler](MinizincHandler.html) behaviour.
  
  
  Solution handler code acts as a callback for the [solver events](#solver-events) emitted by [MinizincPort](https://github.com/bokner/solverl/blob/master/lib/minizinc_port.ex),
  which is a wrapper process for Minizinc executable (see [Under the hood](#under-the-hood) for more details).
  
  
  In case the solution handler is a function, its signature has to have 2 arguments, 1st one is an atom
  denoting the [solver event](#solver-events) type (i.e., :solution, :summary, :minizinc_error), 2nd being the event-specific data of that event.
  
  In case the solution handler is a module that implements [MinizincHandler](MinizincHandler.html) behaviour,
  its functions `handle_solution/1`, `handle_summary/1`, `handle_minizinc_error/1` take an [event-specific data](#event-specific-data).   
  
### Solver events 

Solver event is a tuple {`event_type`, `event_data`}.

Currently, there are following types of solver events:

- `:solution` - the new solution detected;
- `:summary`  - the wrapper sent the summary metadata (usually because the solver had finished);
- `:minizinc_error` - the wrapper detected Minizinc runtime error.

#### Event-specific data
  - **For `:solution` event:** 
  ```elixir
   %{
     data: data,            # Map of values keyed with their variable names
     timestamp: timestamp,  # Timestamp of the moment solution was parsed
     index: index,          # Sequential number of the solution
     stats: stats           # Map of solution statistics values keyed with the field names
     } 
   ```
       
  - **For `:summary` event:** 
  ```elixir
    %{
      status: status,                   # Solver status (one of :satisfied, :unsatisfiable etc)         
      fzn_stats: fzn_stats,             # Map of FlatZinc statistics values keyed with the field names
      solver_stats: solver_stats,       # Map of solver statistics values keyed with the field names
      solution_count: solution_count,   # Total number of solutions found
      last_solution: solution,          # Data for last :solution event (see above)
      minizinc_output: minizinc_output, # Minizinc errors and warnings
      time_elapsed: time_elapsed        # Time elapsed, verbatim as reported by Minizinc 
      }
  ```
  
  - **For `:minizinc_error` event:**
  ```elixir
      %{
        error: error     # Minizinc output accompanied by runtime error 
      }
  ```
  
#### Customizing results and controlling execution.
 
  
  Solution handlers can modify or ignore data passed by solver events, or interrupt the solver process early,
  by constructing their returns in desired form.
  
  The return of the solution handler callback could be one of:
    
- `:stop`
   
   Solution handler stops receiving solver events and asks solver to stop execution.

- `{:stop, data}`
   
   Same as above, but in case of synchronous solving, `data` will be added to [solver results](#solver-results).

- `:skip`
   
   The event will be ignored, i.e. in case of synchronous solving, the results will not be changed. 

- `data :: any()`
   
   In case of synchronous solving, data will be added to [solver results](#solver-results).
   
### Solver results

**Note: this is applicable only to a synchronous solving.**
    
   `Solver results` is a map with the following keys:
   
 - `:solutions` - list of data elements, accumulated by handling of `:solution` events
 - `:summary`  -  data, produced by handling of `:summary` event
 - `:minizinc_error` - data, produced by handling of `:minizinc_error` event

Please refer to [Event-specific data](#event-specific-data) for description of data for solver events.

### Handling exceptions

Solution handler is a pluggable code that is typically created by a user. MinizincSolver catches exceptions from solution handlers
to make sure that the solver process is gracefully shut down. Moreover, in case of synchronous solving,
MinizincSolver preserves the solver results accumulated before the exception, and returns them to the calling process.
The exception value will be added to [solver results](#solver-results) under `:handler_exception` key.



## Model solving examples
 - [N-Queens](#n-queens)
 - [Sudoku](#sudoku)
 - [Graph Coloring](#graph-coloring)
 - [More examples in unit tests](https://github.com/bokner/solverl/blob/master/test/solverl_test.exs)
 
### N-Queens

- [Source code](https://github.com/bokner/solverl/blob/master/examples/nqueens.ex)
- [Model](https://github.com/bokner/solverl/blob/master/mzn/nqueens.mzn)

   The following code solves [N-queens](https://developers.google.com/optimization/cp/queens) puzzle for N = 4:
   
   ```elixir
   NQueens.solve(4, [solution_handler: &NQueens.solution_handler/2])
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

- [Source code](https://github.com/bokner/solverl/blob/master/examples/sudoku.ex)
- [Model](https://github.com/bokner/solverl/blob/master/mzn/sudoku.mzn)

```elixir

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

### Graph coloring

- [Source code](https://github.com/bokner/solverl/blob/master/examples/graph_coloring.ex)
- [Model](https://github.com/bokner/solverl/blob/master/mzn/graph_coloring.mzn)


The model's objective is to minimize the number of colors for proper [Graph Vertex Coloring](https://www.wikiwand.com/en/Graph_coloring#/Vertex_coloring).
```elixir
edges = [
  [0, 1], [1, 2], [1, 3]
  ]
vertices = 4
## Color graph with time limit of 1 sec:
GraphColoring.do_coloring({vertices, edges}, [time_limit: 1*1000])   
```
Output:
```erlang

22:43:01.318 [info]  Found coloring to 2 colors
 
22:43:01.328 [info]  Best coloring found: 2 colors

22:43:01.328 [info]  Optimal? Yes

22:43:01.328 [info]  Color 1 -> vertices: 0, 2, 3

22:43:01.328 [info]  Color 2 -> vertices: 1
```


## Erlang interface

[`minizinc` module](https://github.com/bokner/solverl/blob/master/src/minizinc.erl) mirrors all exported functions of [MinizincSolver module](MinizincSolver.html).

Once you manage to make `solverl` dependency part of your Erlang application build (for instance with [rebar_mix](https://github.com/Supersonido/rebar_mix)),
you should be able to use its interface.
 
Example:

```erlang
results = minizinc:solve_sync(<<"mzn/nqueens.mzn">>, #{n=> 4}, [{solution_handler, fun 'Elixir.NQueens':solution_handler/2}]).
```  

Note: Please use `binary` strings as opposed to `char` strings whenever you need to pass a string to API.
The API functions will always use `binary` strings whenever the function return needs to use strings. 

## Under the hood

Both **MinizincSolver.solve/3** and **MinizincSolver.solve_sync/3** use **MinizincPort.start_link/3**
to start *GenServer* process, which in turn spawns the external MiniZinc process, 
and then parses its text output into solver events and makes appropriate callback function calls as described [here](#solution-handlers).

## Roadmap

```
  Support LNS;
  Support Branch-and-Bound;
  Provide API for peeking into a state of Minizinc process, such as time since last solution,
  whether it's compiling or solving at the moment etc.
  Match minizinc-python functionality.
```  
## Credits

The project extensively uses ideas and code examples from [Minizinc Python](https://minizinc-python.readthedocs.io/en/0.3.0/index.html).
