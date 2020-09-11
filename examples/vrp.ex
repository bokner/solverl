defmodule VRP do
  @moduledoc false

  import MinizincUtils

  @vrp_model resource_file("mzn/vrp.mzn")

  def solve(datafile, opts \\ [], distance_scale \\ 1) when is_integer(distance_scale) do
    ## Extract data
    data = extract_data(datafile, distance_scale)
    MinizincSolver.solve_sync(@vrp_model, Map.delete(data, :locations), opts)
  end


  def extract_data(datafile, distance_scale \\ 1) do

    [header | customers] = String.split(File.read!(resource_file(datafile)), "\n")

    [customer_count, vehicle_count, vehicle_capacity] =
      Enum.map(String.split(header), fn n -> MinizincUtils.parse_value(n) end)

    {demand, coords} = Enum.reduce(
      customers,
      {[], []},
      fn c, {d_acc, p_acc} = acc ->
        case String.split(c) do
          [d, p1, p2] ->
            {
              [MinizincUtils.parse_value(d) | d_acc],
              [{MinizincUtils.parse_value(p1), MinizincUtils.parse_value(p2)} | p_acc]
            }
          _other ->
            acc
        end
      end
    )

    ## Create a distance matrix
    distances = for p1 <- coords do
      for p2 <- coords do
        round(Distance.distance(p1, p2)*distance_scale)
      end
    end

    ## Pack data into a map
    %{
      n: customer_count - 1,
      m: vehicle_count,
      capacity: vehicle_capacity,
      demand: demand,
      distance: distances,
      locations: coords,
      max_stops: calc_max_stops(demand, vehicle_capacity)
    }


  end

  ## Calculate maximum of customers visited by a single vehicle.
  ## Take the smallest values for which the sum does not exceed the capacity
  defp calc_max_stops(demand, vehicle_capacity) do
    {_max_demand, stops} = Enum.reduce(
      Enum.sort(demand),
      {0, 0},
      fn (d, {demand_acc, stop_acc} = acc) ->
        if (d > 0 and (demand_acc + d <= vehicle_capacity)) do
          {demand_acc + d, stop_acc + 1}
        else
          acc
        end

      end
    )

    stops
  end

end