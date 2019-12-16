#! /usr/bin/env elixir
defmodule Day8 do
  def layers(digits, width, ht) do
    digits
    |> String.trim
    |> String.split("", trim: true)
    |> Enum.chunk_every( width*ht )
  end

  def part1(layers) do
    chosen_layer = layers |> Enum.min_by(fn layer->count(layer, "0") end)
    IO.inspect(chosen_layer, label: "chosen_layer")
    IO.inspect(count(chosen_layer, "1"), label: "ones")
    IO.inspect( count(chosen_layer, "2"), label: "twos")
    count(chosen_layer, "1") * count(chosen_layer, "2")
  end

  def count(layer, digit) do
    layer
    |> Enum.count(fn d -> d==digit end)
  end

  def display(layers, width, _ht) do
    pixel_codes = Enum.zip(layers)
    
    pixel_codes
    |> Enum.chunk_every(width)
    |> Enum.map(fn row -> Enum.map(row, fn el -> pixel(el) end) end)
    |> Enum.each(&IO.puts/1)
  end

  def pixel(tuple) do
    t = Tuple.to_list(tuple)
    case Enum.find(t, fn c -> c != "2" end) do
      "0" -> ?#
      "1"-> ?.
    end
  end

end


case System.argv do
  ["--test"] -> ExUnit.start()
    defmodule Day8Test do
      use ExUnit.Case

      # test "initial fuel" do
      #     assert Day8.run(Day8.init("1002,4,3,4,33"), 0,0) == 2
      #   end
      #      test "part2 " do
      #        assert Day8.run(Day8.init("3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99"), 8,0) == 2
      #        #assert Day8.run(Day8.init("3,12,6,12,15,1,13,14,13,4,13,99,-1,0,1,9"), 0,0) == 2
      #        #assert Day8.run(Day8.init("3,3,1105,-1,9,1101,0,0,12,4,12,99,1"), 0,0) == 2
      #        #assert Day8.run(Day8.init("5,9,10,104,0,99,104,1,99,1,6"), 0,0) == 2
      #      end
      test "parse input" do
        IO.inspect Day8.layers("113333555666", 3,4)
        Day8.layers("113333555666", 3,4) == [ ~w(1 1 3), ~w(3 3 3), ~w(5 5 5), ~w(6 6 6)]
      end
    end


  [input_file] -> layers = Day8.layers(File.read!(input_file), 25, 6)
                  IO.inspect(Enum.map(layers, fn l -> Day8.count(l, "0") end))
                  Day8.part1(layers) |> IO.inspect(label: "step1")
                  Day8.display(layers, 25, 6)

  _ -> IO.puts("expected --test or input_file")
  #    System.halt(1)
end
