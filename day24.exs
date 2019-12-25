#! /usr/bin/env elixir
# defmodule Edge do
#   defstruct from: nil, to: nil, distance: 0
# end

defmodule RecursiveMap do
  defstruct levels: %{}, minute: 0

  @empty_map for(
               i <- 0..4,
               j <- 0..4,
               (fn a, b -> a != 2 or b != 2 end).(i, j),
               do: {{i, j}, :empty}
             )
             |> Map.new()

  def new(map) do
    # the recursive hole
    map = Map.delete(map, {2, 2})
    %RecursiveMap{levels: Map.new([{0, map}])}
  end

  def iterate(%RecursiveMap{} = r) do
    lvls =
      r.levels
      |> Map.put(r.minute + 1, @empty_map)
      |> Map.put(-r.minute - 1, @empty_map)

    new_levels =
      lvls
      |> Enum.reduce(%{}, &iterate_level(&1, &2, r))

    %RecursiveMap{r | levels: new_levels, minute: r.minute + 1}
  end

  def iterate_level({i, map}, acc, r) do
    new_map =
      Enum.map(map, fn {loc, curr_state} ->
        adj_bugs =
          neighbors({i, loc})
          |> count_bugs(r)

        {loc, new_state(curr_state, adj_bugs)}
      end)
      |> Map.new()

    Map.put(acc, i, new_map)
  end

  def count_bugs(r) do
    r.levels
    |> Enum.map(fn {_, map} -> Enum.count(map, &(elem(&1, 1) == :bug)) end)
    |> Enum.sum()
  end

  def count_bugs(nbrs, r) do
    nbrs
    |> Enum.count(fn {i, loc} -> Map.get(r.levels, i, @empty_map) |> Map.get(loc) == :bug end)
  end

  def new_state(curr_state, count) do
    case curr_state do
      :bug -> if count == 1, do: :bug, else: :empty
      :empty -> if count == 1 || count == 2, do: :bug, else: :empty
    end
  end

  def count_neighboring_bugs({{x, y} = loc, content}, map) do
    count =
      [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}]
      |> Enum.map(&Map.get(map, &1, :empty))
      |> Enum.count(&(&1 == :bug))

    {loc, {content, count}}
  end

  def neighbors({i, {x, y}}) do
    [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}]
    |> Enum.flat_map(fn {a, b} ->
      case Map.get(@empty_map, {a, b}, false) do
        false ->
          case {a, b} do
            {-1, _} ->
              [{i + 1, {1, 2}}]

            {5, _} ->
              [{i + 1, {3, 2}}]

            {_, -1} ->
              [{i + 1, {2, 1}}]

            {_, 5} ->
              [{i + 1, {2, 3}}]

            {2, 2} ->
              case {x, y} do
                {2, 1} -> for k <- 0..4, do: {i - 1, {k, 0}}
                {3, 2} -> for k <- 0..4, do: {i - 1, {4, k}}
                {2, 3} -> for k <- 0..4, do: {i - 1, {k, 4}}
                {1, 2} -> for k <- 0..4, do: {i - 1, {0, k}}
              end
          end

        _ ->
          [{i, {a, b}}]
      end
    end)
  end
end

defmodule Day24 do
  def part2(map) do
    recursive_map = RecursiveMap.new(map)

    {r, minute} =
      Stream.iterate(recursive_map, &RecursiveMap.iterate/1)
      |> Stream.with_index()
      |> Stream.drop(200)
      |> Enum.take(1)
      |> hd

    IO.puts("MInutes is #{minute}")
    RecursiveMap.count_bugs(r)
  end

  def init(raw) do
    raw
    |> String.split("\n", trim: true)
    |> Enum.with_index()
    |> Enum.flat_map(&map_bugs/1)
    |> Map.new()
  end

  def map_bugs({line, line_number}) do
    line
    |> to_charlist
    |> Enum.with_index()
    |> Enum.map(fn {c, x} -> {{x, line_number}, content(c)} end)
  end

  def content(?#), do: :bug
  def content(?.), do: :empty

  def part1(map) do
    map =
      Stream.iterate(map, &iterate_tiles/1)
      |> Stream.with_index()
      |> Enum.reduce_while(MapSet.new(), fn {map, iteration}, seen ->
        if rem(iteration, 20) == 0 do
          IO.inspect({iteration, MapSet.size(seen)})
        end

        bugs = filter_bugs(map)

        case MapSet.member?(seen, bugs) do
          true ->
            {:halt, map}

          false ->
            {:cont, MapSet.put(seen, bugs)}
        end
      end)

    biodiversity(map)
  end

  def biodiversity(map) do
    filter_bugs(map)
    |> Enum.reduce(0, fn {{x, y}, :bug}, acc -> power(2, 5 * y + x) + acc end)
  end

  def power(b, e), do: :math.pow(b, e) |> trunc

  def filter_bugs(map) do
    Enum.filter(map, fn
      {loc, :bug} -> true
      {loc, :empty} -> false
    end)
  end

  def iterate_tiles(map) do
    map
    |> Enum.flat_map(&update_tile(map, &1))
    |> Map.new()
  end

  def update_tile(map, tile) do
    map
    |> Enum.map(&count_neighboring_bugs(&1, map))
    |> Enum.map(fn {loc, {contents, count}} ->
      case contents do
        :bug -> if count == 1, do: {loc, :bug}, else: {loc, :empty}
        :empty -> if count == 1 || count == 2, do: {loc, :bug}, else: {loc, :empty}
      end
    end)
  end

  def count_neighboring_bugs({{x, y} = loc, content}, map) do
    count =
      [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}]
      |> Enum.map(&Map.get(map, &1, :empty))
      |> Enum.count(&(&1 == :bug))

    {loc, {content, count}}
  end

  def part2({map, labels}) do
  end
end

case System.argv() do
  ["--test"] ->
    ExUnit.start()

    defmodule Day24Test do
      use ExUnit.Case

      test "even bigger test" do
        inp =
          Day24.init("""
          ....#
          #..#.
          #..##
          ..#..
          #....
          """)

        assert Day24.count_neighboring_bugs({{0, 0}, :foo}, inp) == {{0, 0}, {:foo, 1}}
        Day24.part1(inp) |> IO.inspect(label: "part1")

        # IO.inspect(inp)
        # t = Day24.part1(inp) |> IO.inspect(label: "part1")
        # t2 = Day24.part2(inp)
        #    assert Map.values(t2.distances) == [396]
      end

      test "nested nbrs" do
        RecursiveMap.neighbors({2, {2, 1}}) |> IO.inspect()
      end
    end

  [input_file] ->
    inp = Day24.init(File.read!(input_file))

    Day24.part1(inp) |> IO.inspect(label: "part1")

    Day24.part2(inp) |> IO.inspect(label: "part2")

  #                p1 = Day24.part1(program) |> IO.inspect(label: "part1")
  # Day24.part2(program) |> IO.inspect(label: "part2")

  #                  Day24.run(program, [2]) |> IO.inspect(label: "part2")
  #            IO.inspect(Enum.map(layers, fn l -> Day24.count(l, "0") end))
  #                Day24.part1(layers) |> IO.inspect(label: "step1")
  #                Day24.display(layers, 25, 6)

  _ ->
    IO.puts("expected --test or input_file")
    #    System.halt(1)
end
