#! /usr/bin/env elixir
defmodule Day16 do
  def init(raw) do
    raw
    |> String.split("", trim: true)
    |> Enum.reject(&(&1=="\n"))
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
  end

  def part1(input, phases) do
    Stream.iterate(phase(input, length(input)), &phase(&1, length(input)))
    |> Stream.drop(phases-1)
    |> Enum.take(1)
    |> hd
    |> slice_digits(8, 0)
  end

  def slice_digits(codes, num, skip) do
    codes
    |> Enum.slice(skip, skip+num)
    |> Enum.map(&Integer.to_string/1)
    |> Enum.join("")
  end

  def part2(input, phases) do
    repeated_input = Stream.cycle(input)
    |> Stream.take(10_000 * length(input))
     
    codes = Stream.iterate(phase(repeated_input, 10_000*length(input)), &phase(&1, 10_000*length(input)))
    |> Stream.drop(phases-1)
    |> Enum.take(1)
    |> hd
    |> IO.inspect(label: "after hd part2")

    offset = codes |> slice_digits(7,0) |> IO.inspect(label: "offset")
    msg = codes |> slice_digits(8, offset)
  end


  @base_pattern [0, 1, 0, -1]
  @skip 1
  def pattern(1), do: Stream.cycle(@base_pattern) |> Stream.drop(1)
  def pattern(n) do
    len = length(@base_pattern)
    Stream.iterate(%{index: 0, count: @skip}, fn(%{index: idx, count: count})->
      case count+1 == n do
        true -> %{ index: rem(idx+1, len), count: 0}
        _ -> %{index: idx, count: count+1}
      end
    end)
    |> Stream.map(fn(%{index: index})->Enum.at(@base_pattern, index) end)
  end

  def phase(input, len \\ nil) do
    len = if is_nil(len), do: length(input), else: len
    if len>100_000, do: IO.puts("phase #{len}")

    (1..len)
    |> Stream.map(&pattern(&1))
    |> Stream.map(&apply_pattern(&1, input))
  end
  def apply_pattern(p, input) do
    input
    |> Stream.zip(p)
    |> Stream.map(&(elem(&1, 0) * elem(&1, 1)))
    |> Enum.sum
    |> to_digit
  end
  def to_digit(n) do
    case n>0 do
      true -> rem(n,10)
      _ -> rem(-n, 10)
    end
  end


end


case System.argv do
  ["--test"] -> ExUnit.start()
    defmodule Day16Test do
      use ExUnit.Case

      # test "initial fuel" do
      #     assert Day16.run(Day16.init("1002,4,3,4,33"), 0,0) == 2
      #   end
      #      test "part2 " do
      #        assert Day16.run(Day16.init("3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99"), 8,0) == 2
      #        #assert Day16.run(Day16.init("3,12,6,12,15,1,13,14,13,4,13,99,-1,0,1,9"), 0,0) == 2
      #        #assert Day16.run(Day16.init("3,3,1105,-1,9,1101,0,0,12,4,12,99,1"), 0,0) == 2
      #        #assert Day16.run(Day16.init("5,9,10,104,0,99,104,1,99,1,6"), 0,0) == 2
      #      end

      test "pattern" do
        assert Day16.pattern(1) |> Enum.take(10) == [1,0,-1,0,1,0,-1,0,1,0]
        assert Day16.pattern(3) |> Enum.take(10) == [0,0,1,1,1,0,0,0,-1,-1]
      end
      test "simple phase" do
        input = [1,2,3,4,5,6,7,8]
        assert Day16.phase(input) |> Enum.map(&Integer.to_string/1) |> Enum.join("") == "48226158"
      end

      @tag timeout: :infinity
      test "phase2" do
        input = "03036732577212944063491565474664" |> Day16.init
        assert Day16.part2(input, 100) == "84462026"
      end
    end


  [input_file] -> input = Day16.init(File.read!(input_file))
                  Day16.part1(input, 100) |> IO.inspect(label: "part1")
  #Day16.part2(program) |> IO.inspect(label: "part2")
                  #                  Day16.run(program, [2]) |> IO.inspect(label: "part2")
  #            IO.inspect(Enum.map(layers, fn l -> Day16.count(l, "0") end))
  #                Day16.part1(layers) |> IO.inspect(label: "step1")
  #                Day16.display(layers, 25, 6)

  _ -> IO.puts("expected --test or input_file")
  #    System.halt(1)
end

