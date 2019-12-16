#! /usr/bin/env elixir
defmodule Day10 do
  def init(txt) do
    txt
    |> String.split("\n", trim: true)
    |> Enum.map(fn line -> String.split(line, "", trim: true) end)
    |> Enum.with_index
    |> Enum.flat_map(&asteroid_coords_for_row(&1))
  end

  def asteroid_coords_for_row({row, row_coord}) do
    row
    |> Enum.with_index
    |> Enum.map(fn {".", i} -> nil
                   {"#",i} -> {i, row_coord}
                end)
    |> Enum.filter(&(&1))
    #|> IO.inspect
  end

  def part1(roids) do
    num_other_roids = length(roids) - 1

    vecs = offset_map(roids)
    vecs
    #|> IO.inspect
    |> Enum.map(fn({a,offsets}) -> {a, num_other_roids - count_positive_multiples(offsets)} end)
    |> Enum.max_by(fn({a, count_visible}) -> count_visible end)
  end

  def part2(roids) do
    {station, visible} = part1(roids)
    vecs = offset_map(roids)
    offsets = vecs[station]
    IO.inspect(station, label: "station for part2")
    offsets_by_slope = 
      offsets
      |> Enum.map(&slope/1)
      |> Enum.group_by(fn({quad, slope, _, _}) -> {quad, slope} end)
      |> Enum.sort
    
    find_hit(200, offsets_by_slope, [], nil)
  end

  def find_hit(0, offsets_by_slope, next_cycle_offsets, last_hit), do: last_hit
  def find_hit(count, [], next_cycle_offsets, last_hit) do
    IO.inspect(Enum.reverse(next_cycle_offsets) |> Enum.take(3))
    find_hit(count, Enum.reverse(next_cycle_offsets), [], last_hit)
  end
  def find_hit(count, offsets_by_slope, next_cycle_offsets, last_hit) do
    [{firing_dir, in_sight} | next_offsets_by_slope] = offsets_by_slope

    target = Enum.min_by(in_sight, fn({_,_, abs_dy, abs_dx}) -> {abs_dy, abs_dx} end)
    IO.inspect({ target, in_sight})
    now_in_sight = Enum.reject(in_sight, &(&1==target))
    case Enum.empty?(now_in_sight) do
      false -> find_hit(count-1, next_offsets_by_slope,  [{firing_dir, now_in_sight} | next_cycle_offsets], target)
      true -> find_hit(count-1, next_offsets_by_slope,  next_cycle_offsets, target)
    end
  end

  def slope({dx,dy}) do
    quadrant = cond do
      dy<0 && dx>=0 -> 1
      dy>=0 && dx>0 -> 2
      dy>0 && dx<=0 -> 3
      dy<=0 && dx<0 -> 4
    end
    if dx == 0 do
      {quadrant, -999999999, 0, abs(dy)}
    else
      {quadrant, Float.round(dy/dx, 4), abs(dx), abs(dy)}
    end
  end



  def count_positive_multiples(offsets) do
    offsets
    |> Enum.map(fn {ai,aj} = a ->
      Enum.any?(offsets, &is_positive_multiple?(a, &1))
    end)
    |> Enum.count(&(&1))
  end

  def is_positive_multiple?({ai,aj} = a, {bi, bj}) do
    cond do # no offsets are {0,0}
      ai != 0 -> if (ai*bj == aj*bi && bi/ai > 1), do: true, else: false
      aj != 0 -> if (ai*bj == aj*bi && bj/aj > 1), do: true, else: false
    end
  end


  def offset_map(roids) do
    offsets = roids
    |> Enum.map(&calc_offsets(roids, &1))

    Enum.zip(roids, offsets)
    |> Map.new
  end

  def calc_offsets(roids, {ax,ay}) do
    roids
    |> Enum.map(fn
      {^ax, ^ay} -> nil
      {x,y} -> {x-ax, y-ay} end)
    |> Enum.filter(&(&1))
  end
end


case System.argv do
  ["--test"] -> ExUnit.start()
    defmodule Day10Test do
      use ExUnit.Case

      test "parse input" do
        assert length(Day10.init("""
            .#..#
            .....
            #####
            ....#
            ...##
            """)) == 10
      end

      test "calc vectors" do
        asteroids = Day10.init("""
            .#..#
            .....
            #####
            ....#
            ...##
            """)
        vecs = Day10.offset_map(asteroids)
        #IO.inspect vecs
        assert Enum.any?(vecs[{1,0}], fn v -> v=={2,4} end)
        # assert Day10.part1(asteroids) = {{3,4}, 8}
      end

      test "count multiples" do
        offsets = [
                    {1, -2},
                    {4, -2},
                    {1, 0},
                    {2, 0},
                    {3, 0},
                    {4, 0},
                    {4, 1},
                    {3, 2},
                    {4, 2}
                  ]
        assert Day10.count_positive_multiples(offsets) == 3
      end
      test "part2" do
        roids = Day10.init("""
                  .#..##.###...#######
                  ##.############..##.
                  .#.######.########.#
                  .###.#######.####.#.
                  #####.##.#.##.###.##
                  ..#####..#.#########
                  ####################
                  #.####....###.#.#.##
                  ##.#################
                  #####.##.###..####..
                  ..######..##.#######
                  ####.##.####...##..#
                  .#####..#.######.###
                  ##...#.##########...
                  #.##########.#######
                  .####.#.###.###.#.##
                  ....##.##.###..#####
                  .#.#.###########.###
                  #.#.#.#####.####.###
                  ###.##.####.##.#..##
                  """)
        IO.inspect( Day10.part2(roids), label: "part2")
      end

    end


  [input_file] -> roids = Day10.init(File.read!(input_file))
        IO.inspect( Day10.part1(roids), label: "part1")
        IO.inspect( Day10.part2(roids), label: "part2")
  #                  IO.inspect(Enum.map(layers, fn l -> Day10.count(l, "0") end))
  #                  Day10.part1(layers) |> IO.inspect(label: "step1")
  #                  Day10.display(layers, 25, 6)

  _ -> IO.puts("expected --test or input_file")
  #    System.halt(1)
end
