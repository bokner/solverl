defmodule MinizincUtils do
  @moduledoc false

  require Logger
  require Record
  Record.defrecord :instance_rec,
                   [
                     status: nil,
                     solver_stats: %{},
                     mzn_stats: %{},
                     solution_data: %{},
                     time_elapsed: nil,
                     misc: %{},
                     json_buffer: "",
                     unhandled_output: "",
                     timestamp: nil,
                     solution_count: 0
                   ]
end
