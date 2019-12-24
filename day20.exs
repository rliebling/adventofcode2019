#! /usr/bin/env elixir
# defmodule Edge do
#   defstruct from: nil, to: nil, distance: 0
# end

defmodule Graph do
  defstruct neighbors: %{}, distances: %{}, portals: %{}

  def new(map, portals), do: new(map, portals, connect_portals(portals))

  def new(map, portals, portal_edges) do
    edges = map |> Enum.flat_map(&direct_edges(&1, map))

    g = Enum.reduce(edges ++ portal_edges, %Graph{}, &build_neighbors_and_distances/2)

    g =
      Enum.reduce(
        Map.keys(g.neighbors),
        g,
        &eliminate_empties(&2, &1, map)
      )

    %Graph{g | portals: portals}
  end

  def new_recursive(map, {entrance, exit}, outer_portals, inner_portals, depth) do
    map =
      map
      |> Map.put(entrance, :entrance)
      |> Map.put(exit, :exit)

    map =
      outer_portals
      |> IO.inspect(label: "outers")
      |> Enum.reduce(map, fn {label, pt}, acc -> Map.put(acc, pt, label) end)

    map =
      inner_portals
      |> IO.inspect(label: "inners")
      |> Enum.reduce(map, fn {label, pt} = e, acc ->
        Map.put(acc, pt, label)
      end)

    Enum.reject(map, fn {loc, type} -> type == :empty end)
    |> IO.inspect(label: "nonempty b/f Graph")

    g = Graph.new(map, [])

    IO.inspect(g, label: "non-recursive g")

    g = glue_graph_copies(g, depth, outer_portals, inner_portals)

    to_make_empty =
      for(
        {_label, p2} <- outer_portals,
        d <- 0..depth,
        do: make_depth(p2, d)
      ) ++
        for({_label, p2} <- inner_portals, d <- 0..depth, do: make_depth(p2, d)) ++
        Enum.flat_map(1..depth, &[make_depth(entrance, &1), make_depth(exit, &1)])

    map_no_labels = Enum.reduce(to_make_empty, map, &Map.put(&2, &1, :empty))

    g =
      Enum.reduce(
        Map.keys(g.neighbors),
        g,
        &eliminate_empties(&2, &1, map_no_labels)
      )

    IO.inspect(g, label: "recursive graph")
  end

  def glue_graph_copies(g, depth, outer_portals, inner_portals) do
    nbrs =
      g.neighbors
      |> Enum.reduce(%{}, &make_nbr_layers(&1, &2, depth))

    distances =
      g.distances
      |> Enum.reduce(%{}, &make_distance_layers(&1, &2, depth))

    %{distances: distances, neighbors: nbrs} =
      Enum.reduce(0..(depth - 1), %{distances: distances, neighbors: nbrs}, fn d, dist_nbrs ->
        Enum.reduce(inner_portals, dist_nbrs, fn {label, pt}, dn ->
          inn = make_depth(pt, d)
          out = make_depth(outer_portals[label], d + 1)
          ds = Map.put(dn[:distances], make_edge(inn, out), 1)

          ns =
            dn[:neighbors]
            |> Map.update(inn, MapSet.new([out]), &MapSet.put(&1, out))
            |> Map.update(out, MapSet.new([inn]), &MapSet.put(&1, inn))

          %{distances: ds, neighbors: ns}
        end)
      end)

    %Graph{g | distances: distances, neighbors: nbrs}
  end

  def make_nbr_layers({p, set}, nbrs, depth) do
    Enum.reduce(0..depth, nbrs, fn d, acc ->
      p3 = make_depth(p, d)
      p3nbrs = Enum.reduce(set, MapSet.new(), &MapSet.put(&2, make_depth(&1, d)))
      Map.put(acc, p3, p3nbrs)
    end)
  end

  def make_distance_layers({{p1, p2}, dist}, dists, depth) do
    Enum.reduce(0..depth, dists, fn d, acc ->
      edge = make_edge(make_depth(p1, d), make_depth(p2, d))
      Map.put(acc, edge, dist)
    end)
  end

  def make_edge(p1, p2), do: if(p1 < p2, do: {p1, p2}, else: {p2, p1})
  def make_depth({x, y}, d), do: {x, y, d}

  def connect_portals(portals) do
    portal_edges =
      portals
      |> Enum.reject(fn {_key, locs} -> length(locs) == 1 end)
      |> Enum.map(fn {_key, [p1, p2]} -> if p1 < p2, do: {p1, p2}, else: {p2, p1} end)
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
      _other -> g
    end
  end

  def eliminate_node(g, loc) do
    IO.puts("eliminate_node #{inspect(loc)}")

    pairs =
      for p1 <- g.neighbors[loc],
          p2 <- g.neighbors[loc],
          (fn a, b ->
             a < b
           end).(p1, p2),
          do: {p1, p2}

    if length(pairs) == 0, do: IO.inspect(g.neighbors[loc], label: "no pairs of new nbrs?")
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
    IO.inspect({p1, p2}, label: "make_neighbors")

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

defmodule Day20 do
  def init(raw) do
    numbered_lines =
      raw
      |> String.split("\n", trim: true)
      |> Enum.with_index(-2)

    labels = make_labels(numbered_lines)

    map =
      numbered_lines
      |> Enum.reject(fn {l, _} -> String.match?(l, ~r(^\s\s\s)) end)
      |> Enum.map(fn {l, y} -> {String.slice(l, 2, String.length(l) - 4), y} end)
      |> Enum.flat_map(&numbered_line_to_pairs/1)
      |> Map.new()

    {map, labels}
  end

  def make_labels(numbered_lines) do
    vertical_regex = ~r( [[:alpha:]] )

    %{labels: vert_labels} =
      numbered_lines
      |> Stream.chunk_every(2, 1)
      |> Stream.filter(fn
        [{f, _}, {s, _}] ->
          String.match?(f, vertical_regex) && String.match?(s, vertical_regex)

        [_] ->
          false
      end)
      |> Enum.to_list()
      |> Enum.reduce(%{above_or_below: :below, labels: %{}}, fn [{f, y1}, {s, y2}], acc ->
        y = if acc[:above_or_below] == :below, do: y2 + 1, else: y1 - 1

        %{
          labels: add_vertical_labels(acc[:labels], f, s, y),
          above_or_below: if(acc[:above_or_below] == :below, do: :above, else: :below)
        }
      end)

    left_label_regex = ~r([[:alpha:]]{2}\.)

    numbered_lines
    # reject if starts with 3 spaces
    |> Stream.reject(fn {l, _y} -> String.match?(l, ~r(^   )) end)
    |> Enum.reduce(vert_labels, &add_horizontal_labels(&1, &2))
  end

  def add_horizontal_labels({l, y}, labels) do
    chunks =
      l
      |> to_charlist
      |> Enum.chunk_every(3, 1)
      |> Enum.with_index(0)

    chunks
    |> Enum.reduce(labels, fn {chunk, right_x}, labels ->
      case chunk do
        [_, ?., _] ->
          labels

        [_, ?#, _] ->
          labels

        [_, ?\s, _] ->
          labels

        [?\s, _, _] ->
          labels

        [_, _, ?\s] ->
          labels

        [a, b, ?.] ->
          Map.update(labels, to_string([a, b]), [{right_x, y}], &[{right_x, y} | &1])

        [?., b, c] ->
          Map.update(labels, to_string([b, c]), [{right_x - 2, y}], &[{right_x - 2, y} | &1])

        _ ->
          labels
      end
    end)
  end

  def add_vertical_labels(labels, first, second, y) do
    Enum.zip(String.split(first, "", trim: true), String.split(second, "", trim: true))
    |> Enum.with_index(-2)
    |> Enum.reject(fn
      {{" ", _}, _} -> true
      {{"#", _}, _} -> true
      {{".", _}, _} -> true
      {{_, " "}, _} -> true
      {{_, "#"}, _} -> true
      {{_, "."}, _} -> true
      _ -> false
    end)
    |> Enum.reduce(labels, fn {label_tpl, x}, acc ->
      Map.update(acc, to_label(label_tpl), [{x, y}], &[{x, y} | &1])
    end)
  end

  def to_label(tpl), do: tpl |> Tuple.to_list() |> Enum.join("")

  def numbered_line_to_pairs({line, y}) do
    line
    |> String.split("", trim: true)
    |> Enum.with_index()
    |> Enum.flat_map(fn {c, x} ->
      case contents(c) do
        nil -> []
        :empty -> [{{x, y}, :empty}]
        # skip walls
        :wall -> []
        :space -> []
        :letter -> []
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
  def contents(" "), do: :space
  def contents("."), do: :empty
  def contents(letter), do: :letter

  def part1({map, portals}) do
    map = map |> Map.put(hd(portals["AA"]), :entrance) |> Map.put(hd(portals["ZZ"]), :exit)
    graph = Graph.new(map, portals)
  end

  def part2({map, labels}) do
    IO.puts("In part2")
    {{max_x, _}, _} = Enum.max_by(map, fn {{x, y}, _} -> x end)
    {{_, max_y}, _} = Enum.max_by(map, fn {{x, y}, _} -> y end)

    entrance = labels["AA"] |> hd
    exit = labels["ZZ"] |> hd

    {outer_portals, inner_portals} =
      split_portals(labels, max_x, max_y) |> IO.inspect(label: "split portal")

    depth = 30
    g = Graph.new_recursive(map, {entrance, exit}, outer_portals, inner_portals, depth)

    #    copy_map_at_depth = fn d, acc ->
    #      Enum.reduce(map, acc, fn {{x, y}, val}, acc -> Map.put(acc, {x, y, d}, val) end)
    #    end
    #
    #    IO.puts("duplicating map")
    #
    #    map =
    #      Enum.reduce(0..depth, %{}, copy_map_at_depth)
    #      |> Map.put(entrance, :entrance)
    #      |> Map.put(exit, :exit)
    #
    #    IO.puts("map duplicated size #{Map.size(map)}")
    #
    #    IO.inspect(labels, label: "labels")
    #
    #    portal_edges =
    #      for d <- 0..depth, {label, {x1, y1}} = _inner_portal <- inner_portals do
    #        {x2, y2} = outer_portals[label]
    #        {{x1, y1, d}, {x2, y2, d + 1}}
    #      end
    #
    #    IO.inspect(portal_edges, label: "portal edges")
    #
    #    graph = Graph.new(map, labels, portal_edges)
  end

  def split_portals(labels, max_x, max_y) do
    outer_portals =
      labels
      |> Map.delete("AA")
      |> Map.delete("ZZ")
      |> Enum.reduce(%{}, fn {label, locs} = s, acc ->
        Map.put(
          acc,
          label,
          Enum.find(locs, fn
            {0, _} -> true
            {_, 0} -> true
            {^max_x, _} -> true
            {_, ^max_y} -> true
            _ -> false
          end)
        )
      end)
      |> Map.new()

    inner_portals =
      labels
      |> Map.delete("AA")
      |> Map.delete("ZZ")
      |> Enum.reduce(%{}, fn {label, locs}, acc ->
        Map.put(
          acc,
          label,
          Enum.find(locs, fn
            {0, _} -> false
            {_, 0} -> false
            {^max_x, _} -> false
            {_, ^max_y} -> false
            _ -> true
          end)
        )
      end)
      |> Map.new()

    {outer_portals, inner_portals}
  end
end

case System.argv() do
  ["--test"] ->
    ExUnit.start()

    defmodule Day20Test do
      use ExUnit.Case

      #      test "bigger test" do
      # inp =
      #      Day20.init("""
      #               A           
      #               A           
      #        #######.#########  
      #        #######.........#  
      #        #######.#######.#  
      #        #######.#######.#  
      #        #######.#######.#  
      #        #####  B    ###.#  
      #      BC...##  C    ###.#  
      #        ##.##       ###.#  
      #        ##...DE  F  ###.#  
      #        #####    G  ###.#  
      #        #########.#####.#  
      #      DE..#######...###.#  
      #        #.#########.###.#  
      #      FG..#########.....#  
      #        ###########.#####  
      #                   Z       
      #                   Z       
      #      """)
      #
      #    IO.inspect(inp)
      #  # t = Day20.part1(inp) |> IO.inspect(label: "part1")
      #  # t2 = Day20.part2(inp)
      #  # assert Map.values(t2.distances) == [26]
      #
      #  # IO.inspect(t.path)
      # end

      test "even bigger test" do
        inp =
          Day20.init("""
                       Z L X W       C                 
                       Z P Q B       K                 
            ###########.#.#.#.#######.###############  
            #...#.......#.#.......#.#.......#.#.#...#  
            ###.#.#.#.#.#.#.#.###.#.#.#######.#.#.###  
            #.#...#.#.#...#.#.#...#...#...#.#.......#  
            #.###.#######.###.###.#.###.###.#.#######  
            #...#.......#.#...#...#.............#...#  
            #.#########.#######.#.#######.#######.###  
            #...#.#    F       R I       Z    #.#.#.#  
            #.###.#    D       E C       H    #.#.#.#  
            #.#...#                           #...#.#  
            #.###.#                           #.###.#  
            #.#....OA                       WB..#.#..ZH
            #.###.#                           #.#.#.#  
          CJ......#                           #.....#  
            #######                           #######  
            #.#....CK                         #......IC
            #.###.#                           #.###.#  
            #.....#                           #...#.#  
            ###.###                           #.#.#.#  
          XF....#.#                         RF..#.#.#  
            #####.#                           #######  
            #......CJ                       NM..#...#  
            ###.#.#                           #.###.#  
          RE....#.#                           #......RF
            ###.###        X   X       L      #.#.#.#  
            #.....#        F   Q       P      #.#.#.#  
            ###.###########.###.#######.#########.###  
            #.....#...#.....#.......#...#.....#.#...#  
            #####.#.###.#######.#######.###.###.#.#.#  
            #.......#.......#.#.#.#.#...#...#...#.#.#  
            #####.###.#####.#.#.#.#.###.###.#.###.###  
            #.......#.....#.#...#...............#...#  
            #############.#.#.###.###################  
                         A O F   N                     
                         A A D   M                     
          """)

        # IO.inspect(inp)
        # t = Day20.part1(inp) |> IO.inspect(label: "part1")
        t2 = Day20.part2(inp)
        assert Map.values(t2.distances) == [396]
      end
    end

  [input_file] ->
    {map, labels} = inp = Day20.init(File.read!(input_file))

    #    Day20.part1({map, labels}) |> IO.inspect(label: "part1")

    Day20.part2(inp) |> IO.inspect(label: "part2")

  #                p1 = Day20.part1(program) |> IO.inspect(label: "part1")
  # Day20.part2(program) |> IO.inspect(label: "part2")

  #                  Day20.run(program, [2]) |> IO.inspect(label: "part2")
  #            IO.inspect(Enum.map(layers, fn l -> Day20.count(l, "0") end))
  #                Day20.part1(layers) |> IO.inspect(label: "step1")
  #                Day20.display(layers, 25, 6)

  _ ->
    IO.puts("expected --test or input_file")
    #    System.halt(1)
end
