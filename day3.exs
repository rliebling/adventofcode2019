#! /usr/bin/env elixir
defmodule Day3 do

  def init(raw) do
    raw
    |> String.split("\n", trim: true)
    |> Enum.map( fn line ->
      line
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.map(&to_vector/1)
    end)
  end

  def nearest(intersections, min_func \\ &manhattan_min/1) do
    min_func.(intersections)
  end

  defp manhattan_min(intersections) do
    {{x,y}, _, _} = Enum.min_by(intersections, fn {{x,y},_,_} -> abs(x)+abs(y) end)
    abs(x)+abs(y)
  end

  def time_min(intersections) do
    IO.inspect(intersections)
    {_, c1, c2} = Enum.min_by(intersections, fn {{x,y},c1,c2} -> c1+c2 end)
    c1+c2
  end

  def intersections(input) do
    [w1, w2] = input |> Enum.map(&compute_path/1)
    w1_locations = MapSet.new Map.keys(w1[:counted_path])
    w2_locations = MapSet.new Map.keys(w2[:counted_path])

    MapSet.intersection(w1_locations, w2_locations)
    |> Enum.map(fn loc -> {loc, w1[:counted_path][loc], w2[:counted_path][loc]} end)
  end

  def get_path({x,y} = _start, {dir, count}) do
    case dir do
      :right -> (1..count) |> Enum.map(fn count -> {x+count, y} end)
      :left -> (1..count) |> Enum.map(fn count -> {x-count, y} end)
      :up -> (1..count) |> Enum.map(fn count -> {x, y+count} end)
      :down -> (1..count) |> Enum.map(fn count -> {x, y-count} end)
    end
  end

  defp compute_path(steps) do
    start_port = %{current: {0,0}, current_count: 0, counted_path: %{} }
    steps
    |> Enum.reduce(start_port, fn (vector, accum) -> p = get_path(accum[:current], vector)
                            add_path(accum, p) end)
  end


  def add_path(%{current: {x,y}, current_count: cur_count, counted_path: counted_path}, path) do
    new_counted_path = path
                       |> Enum.with_index
                       |> Enum.reduce(counted_path,
                         fn({coords, step},set) -> Map.put_new(set, coords, cur_count+step+1) end)
    %{counted_path: new_counted_path, current: last(path), current_count: cur_count+length(path)}
  end

  def last([h | []]), do: h
  def last([h | tail]) do
    last(tail)
  end

  def to_vector("R" <> count ) do
    {:right, String.to_integer(count)}
  end
  def to_vector("L" <> count ) do
    {:left, String.to_integer(count)}
  end
  def to_vector("U" <> count ) do
    {:up, String.to_integer(count)}
  end
  def to_vector("D" <> count ) do
    {:down, String.to_integer(count)}
  end

end


case System.argv do
  ["--test"] -> ExUnit.start()
    defmodule Day3Test do
      use ExUnit.Case

      test "initial fuel" do
        input = Day3.init("R75,D30,R83,U83,L12,D49,R71,U7,L72\nU62,R66,U55,R34,D71,R55,D58,R83")
        assert Day3.intersections(input)|> Day3.nearest == 159
        assert Day3.intersections(input)|> Day3.nearest(&Day3.time_min/1) == 610
      end
    end

  [input_file] -> input = Day3.init(File.read!(input_file))
                  intersections = Day3.intersections(input) 
                  intersections |> Day3.nearest |> IO.inspect(label: "part1")
                  intersections |> Day3.nearest(&Day3.time_min/1) |> IO.inspect(label: "part2")

  _ -> IO.puts("expected --test or input_file")
    System.halt(1)
end
