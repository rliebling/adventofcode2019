#! /usr/bin/env elixir
# defmodule Edge do
#   defstruct from: nil, to: nil, distance: 0
# end

defmodule Graph do
  defstruct neighbors: %{}, distances: %{}, nodes: %{}, num_keys: 0

  def new(map, _entrance) do
    edges = map |> Enum.flat_map(&direct_edges(&1, map))

    g = Enum.reduce(edges, %Graph{}, &build_neighbors_and_distances/2)

    g =
      Enum.reduce(
        Map.keys(g.neighbors),
        g,
        &eliminate_empties(&2, &1, map)
      )

    build_nodes(g, map)
  end

  def build_nodes(g, map) do
    nodes = Enum.reduce(Map.keys(g.neighbors), %{}, fn p, nodes -> Map.put(nodes, p, map[p]) end)

    num_keys =
      Map.values(nodes)
      |> Enum.sort()
      |> Enum.filter(fn
        {:key, _} -> true
        _ -> false
      end)
      |> Enum.count()

    %Graph{g | nodes: nodes, num_keys: num_keys}
  end

  def build_neighbors_and_distances({p1, p2} = edge, g) do
    distances = Map.put(g.distances, edge, 1)

    neighbors =
      g.neighbors
      |> Map.update(p1, MapSet.new([p2]), &MapSet.put(&1, p2))
      |> Map.update(p2, MapSet.new([p1]), &MapSet.put(&1, p1))

    %Graph{g | neighbors: neighbors, distances: distances}
  end

  def eliminate_empties(g, loc, map) do
    case Map.get(map, loc) do
      :empty -> eliminate_node(g, loc)
      _letter -> g
    end
  end

  def eliminate_node(g, loc) do
    pairs =
      for p1 <- g.neighbors[loc],
          p2 <- g.neighbors[loc],
          (fn a, b ->
             a < b
           end).(p1, p2),
          do: {p1, p2}

    g = Enum.reduce(pairs, g, &make_neighbors(&2, &1, loc))

    loc_neighbors = g.neighbors[loc]
    g = %Graph{g | neighbors: Map.delete(g.neighbors, loc)}

    Enum.reduce(loc_neighbors, g, fn p, g ->
      edge = if p < loc, do: {p, loc}, else: {loc, p}
      distances = g.distances |> Map.delete(edge)
      neighbors = g.neighbors |> Map.update(p, nil, &MapSet.delete(&1, loc))
      %Graph{g | neighbors: neighbors, distances: distances}
    end)
  end

  # assumes p1<p2
  def make_neighbors(g, {p1, p2} = edge, elim_node) do
    # IO.inspect({p1, p2}, label: "make_neighbors")

    d = edge_distance(g, p1, elim_node) + edge_distance(g, p2, elim_node)
    distances = Map.update(g.distances, edge, d, &min(&1, d))

    neighbors =
      g.neighbors
      |> Map.update(p1, MapSet.new([p2]), &MapSet.put(&1, p2))
      |> Map.update(p2, MapSet.new([p1]), &MapSet.put(&1, p1))

    %{g | neighbors: neighbors, distances: distances}
  end

  def direct_edges({{x, y} = loc, _content}, map) do
    # only need to look right and down b/c we'll add both directions when we come to an edge
    [{1, 0}, {0, 1}]
    |> Enum.flat_map(fn {dx, dy} ->
      p = {x + dx, y + dy}
      edge = if p < loc, do: {p, loc}, else: {loc, p}

      case Map.get(map, p, nil) do
        nil -> []
        :wall -> []
        :empty -> [edge]
        :entrance -> [edge]
        _letter -> [edge]
      end
    end)
  end

  def edge_distance(g, p1, p2) do
    edge = if p1 < p2, do: {p1, p2}, else: {p2, p1}
    g.distances[edge]
  end
end

defmodule Day18 do
  def init(raw) do
    map =
      raw
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      # lines with line numbers
      |> Enum.with_index()
      |> Enum.flat_map(&numbered_line_to_pairs/1)
      |> Map.new()

    entrance = Enum.find(map, fn {_loc, content} -> content == :entrance end)
    {map, entrance}
  end

  def numbered_line_to_pairs({line, x}) do
    line
    |> String.split("", trim: true)
    |> Enum.with_index()
    |> Enum.flat_map(fn {c, y} ->
      case contents(c) do
        nil -> []
        :empty -> [{{x, y}, :empty}]
        # skip walls
        :wall -> []
        :entrance -> [{{x, y}, :entrance}]
        letter -> [{{x, y}, letter_node(letter)}]
      end
    end)
  end

  def letter_node(l) do
    c = to_charlist(l) |> hd

    cond do
      ?a <= c && c <= ?z -> {:key, c}
      ?A <= c && c <= ?Z -> {:gate, c + (?a - ?A)}
      true -> raise "ERROR in letter_node"
    end
  end

  def contents("#"), do: :wall
  def contents("@"), do: :entrance
  def contents("."), do: :empty
  def contents(letter), do: letter

  defmodule Traversal do
    defstruct loc: nil, keys: MapSet.new(), distance: 0, graph: nil, path: []

    # return list so can be flat mapped away
    def advance(%Traversal{loc: src, keys: keys, graph: g} = t, dest, add_distance) do
      case g.nodes[dest] do
        {:key, k} ->
          # IO.puts("got key #{k} num nodes #{Map.size(g.neighbors)}")

          [
            %Traversal{
              t
              | keys: MapSet.put(keys, k),
                path: [dest | t.path],
                distance: t.distance + add_distance,
                loc: dest
            }
          ]

        {:gate, k} ->
          case MapSet.member?(keys, k) do
            false ->
              # IO.puts("rejected by gate #{k}")
              []

            true ->
              # IO.puts("got open gate #{k}")

              [
                %Traversal{
                  t
                  | path: [dest | t.path],
                    distance: t.distance + add_distance,
                    loc: dest
                }
              ]

            _ ->
              [t]
          end

        _ ->
          [t]
      end
    end
  end

  def part1({map, {entrance, :entrance}}) do
    graph = Graph.new(map, entrance)

    IO.puts("part1: num_keys to start = #{graph.num_keys} entrance=#{inspect(entrance)}")

    initial_state = [%Traversal{graph: graph, loc: entrance}]

    Stream.iterate(initial_state, &advance_all_traversals/1)
    |> Enum.reduce_while(nil, &found_shortest_path?/2)
  end

  def found_shortest_path?(traversals, _acc) do
    IO.puts(
      "found? #{length(traversals)} max_keys=#{
        Enum.max_by(traversals, fn t -> MapSet.size(t.keys) end).keys |> MapSet.size()
      }"
    )

    all_keys = Enum.filter(traversals, fn t -> MapSet.size(t.keys) == t.graph.num_keys end)

    # IO.puts("found_shortest_path? #{length(all_keys)}")

    case all_keys do
      [] -> {:cont, nil}
      _ -> {:halt, Enum.min_by(all_keys, & &1.distance)}
    end
  end

  def advance_all_traversals(traversals) do
    Enum.flat_map(traversals, &advance_traversal/1)
  end

  def advance_traversal(t) do
    loc = t.loc
    nbrs = Map.get(t.graph.neighbors, loc)

    old_g = t.graph
    new_g = Graph.eliminate_node(t.graph, loc)

    # IO.puts("advance_traversal over #{MapSet.size(nbrs)} neighbors from #{inspect(loc)}")
    Enum.flat_map(
      nbrs,
      &Traversal.advance(%Traversal{t | graph: new_g}, &1, Graph.edge_distance(old_g, loc, &1))
    )
  end

  # find_shortest_path
  # state = set of loc, keys, distance, graph tuples, as the graph will change as we eliminate gates for that partiular traversal
  # starting from {entrance, %MapSet.new, 0}
  # if any states have all keys, eliminate any states w/o lower distance as they are not winners
  # for each possible remaining state:
  # visit all neighbors
  #   * if gate w/no key, eliminate this possibility as there's no value to it
  #   * eliminate node any gates for which have keys - but then state must become each neighbor of that node, except 
  #   returning to same spot

  def part2(_input) do
  end
end

case System.argv() do
  ["--test"] ->
    ExUnit.start()

    defmodule Day18Test do
      use ExUnit.Case

      test "simple graph" do
        inp =
          Day18.init("""
          #########
          #b.A.@.a#
          #########
          """)

        t =
          Day18.part1(inp)
          |> IO.inspect()

        assert t.distance == 8
      end

      test "bigger test" do
        inp =
          Day18.init("""
          ########################
          #...............b.C.D.f#
          #.######################
          #.....@.a.B.c.d.A.e.F.g#
          ########################
          """)

        t = Day18.part1(inp) |> IO.inspect()
        assert t.distance == 132
      end
    end

  [input_file] ->
    {map, entrance} = Day18.init(File.read!(input_file))
    Day18.part1({map, entrance}) |> IO.inspect(label: "part1")

  #                p1 = Day18.part1(program) |> IO.inspect(label: "part1")
  # Day18.part2(program) |> IO.inspect(label: "part2")

  #                  Day18.run(program, [2]) |> IO.inspect(label: "part2")
  #            IO.inspect(Enum.map(layers, fn l -> Day18.count(l, "0") end))
  #                Day18.part1(layers) |> IO.inspect(label: "step1")
  #                Day18.display(layers, 25, 6)

  _ ->
    IO.puts("expected --test or input_file")
    #    System.halt(1)
end
