#! /usr/bin/env elixir
defmodule Day6 do
  def init(raw) do
    raw
    |> String.split("\n", trim: true)
    |> Enum.map(fn pair -> String.split(pair, ")") |> List.to_tuple end)
  end

  def run(input) do
    orbiters = build_orbiters(input)

    orbiters
    |> count_orbits(0, 1, ["COM"])
    |> IO.inspect(label: "step1")
    
    input
    |> build_orbiting
    |> distance("YOU", "SAN")
    |> IO.inspect
  end

  def build_orbiting(input) do
    input
    |> Enum.reduce(%{}, fn {left, right}, acc -> Map.put(acc, right, left) end)
  end

  def build_orbiters(input) do
    input
    |> Enum.reduce(%{}, fn {left, right}, acc -> Map.update(acc, left, [right], fn l->[right | l] end) end)
  end

  def count_orbits(_orbiters, count, _depth, []), do: count
  def count_orbits(orbiters, count, depth, [inner| rest]) do
    #IO.inspect inner
    #IO.inspect Map.get(map, inner, "XXX")
    orbiting_inner = Map.get(orbiters, inner, [])
    count + depth * length(orbiting_inner) + count_orbits(orbiters,0, depth+1, orbiting_inner) + count_orbits(orbiters, 0, depth, rest) 
  end

  def distance(orbiting, src, dest) do
    src_path = build_outward_path(orbiting, src)
    dest_path = build_outward_path(orbiting, dest)
    index_common_ancestor = Enum.zip(src_path, dest_path)
                            |> Enum.find_index(fn {a,b} -> a != b end)
    length(src_path) - 1 + length(dest_path) -1 - 2*index_common_ancestor

  end

  def build_outward_path(orbiting, from, path \\ []) do
    case Map.has_key?(orbiting, from) do
      true -> build_outward_path(orbiting, orbiting[from], [from | path ])
      false -> [from | path]
    end
  end

end


case System.argv do
  ["--test"] -> ExUnit.start()
    defmodule Day6Test do
      use ExUnit.Case

    # test "initial fuel" do
    #     assert Day6.run(Day6.init("1002,4,3,4,33"), 0,0) == 2
    #   end
      test "part2 " do
        """
        COM)B
        B)C
        C)D
        D)E
        E)F
        B)G
        G)H
        D)I
        E)J
        J)K
        K)L
        K)YOU
        I)SAN
        """
        |> Day6.init |> Day6.run
      end
    end
  [input_file] -> input = File.read!(input_file)
                          |> Day6.init
                          |> Day6.run
                          |> IO.puts

  _ -> IO.puts("expected --test or input_file")
  #    System.halt(1)
end
