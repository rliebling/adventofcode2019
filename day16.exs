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
    Stream.iterate(fast_phase2(input, length(input)), &fast_phase2(&1, length(input)))
    |> Stream.drop(phases-1)
    |> Enum.take(1)
    |> hd
    |> slice_digits(8, 0)
  end

  def slice_digits(codes, num, skip) do
    IO.puts "slice #{num} #{skip}"
    codes
    |> Enum.slice(skip, num)
    |> IO.inspect(label: "slice")
    |> Enum.map(&Integer.to_string/1)
    |> Enum.join("")
  end

  def part2(input, phases, copies \\ 10_000) do
    offset = input |> slice_digits(7,0) |> String.to_integer |> IO.inspect(label: "offset")

    repeated_input = Stream.cycle(input)
    |> Enum.take(copies * length(input))
    #|> IO.inspect(label: "repeated_input") 
    IO.puts("part2 input repeated #{copies} times")

    codes = Stream.iterate(fast_phase2(input, copies), &fast_phase2(&1, copies))
    |> Stream.drop(phases-1)
    |> Enum.take(1)
    |> hd
    #    |> IO.inspect(label: "after hd part2")

    
    result = codes |> Enum.map(&Integer.to_string/1)|>Enum.join("") #|> String.to_integer

    #offset = codes |> slice_digits(7,0) |> String.to_integer |> IO.inspect(label: "offset")
    mod_offset = rem(offset, length(input))
    msg = codes |> slice_digits(8, mod_offset)
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


  # FIX after coefficients!!!
  def fast_phase2(input, repeat_times \\ nil) do 
    len = length(input)
    (1..len)
    |> Enum.map(&compute_digit(&1, input))
    # compute it pattern_length times with 0..len-1 offsets
    # combine them?  what about when pattern_length = 4*1million
    #    |> IO.inspect(label: "fast_phase2")
  end

  def compute_digit(n, input, for_coeff \\ false)
  def compute_digit(n, input, true) do
    compute_digit(n, input, false) |> abs
  end
  def compute_digit(n, input, false) do
    # 1:  1 0 -1 0 1 0 -1 0
    # 2:  0 1 1 0 0 -1 -1 0 0
    # 3:  0 0 1 1 1 0 0 0 -1 -1 -1 0
    pattern_length = n*length(@base_pattern)
    first_one = n
    first_minus_one = first_one + 2*n  # skip n 1's and n 0's
    

    # index starts at 1 to skip the first in the pattern
    input
    |> Enum.reduce(%{digit: 0, index: 1}, fn e, %{digit: digit, index: index} ->
      cond do
        first_one<=index && index < first_one+n -> %{digit: digit+e, index: index+1}
        first_minus_one<=index && index< first_minus_one+n-1 -> %{digit: digit-e, index: index+1} #leave a -1 to next case
        index == pattern_length-1 -> %{digit: digit-e, index: 0} # also a -1
        true -> %{digit: digit, index: index+1}
      end
    end)
    |> Map.get(:digit)
    |> rem(10)
    |> abs
    #|> positive_remainder(10)
  end
  def positive_remainder(rem, mod) do
    if rem<0, do: rem+mod, else: rem
  end

  def phase(input, len \\ nil) do
    len = if is_nil(len), do: length(input), else: len
    # if len>100_000, do: IO.puts("phase #{len}")

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
      test "simple part1" do
        raw = "12345678"
        assert Day16.init(raw) |> Day16.part1(4) == "01029498"
        assert Day16.init(raw) |> Day16.part1(1)|>Day16.init |>Day16.part1(1) == "34040438"
      end
      test "simple part1 longer" do
        raw = "80871224585914546619083218645595"
        #assert Day16.init(raw) |> Day16.part1(1) |>Day16.init|> Day16.part1(1) == Day16.init(raw) |> Day16.part1(2)
        assert Day16.init(raw) |> Day16.part1(100) == "24176176"
      end

      @tag timeout: :infinity
      test "phase2" do
        #input = "03036732577212944063491565474664" |> Day16.init
        #input = "01000" |> Day16.init
        #assert Day16.part2(input, 100) == "84462026"
        #
        len = 200
        zeros = List.duplicate(0,len)
        for idx <- 0..(len-1) do
          List.replace_at(zeros, idx, 1) |> Enum.map(&Integer.to_string/1) |> Enum.join("")
          |> Day16.init
          |> Day16.part2(100, 1)
          |> IO.inspect(label: "for #{idx}")
        end
      end
    end


  [input_file] -> input = Day16.init(File.read!(input_file))
                  Day16.part1(input, 100) |> IO.inspect(label: "part1")
                  Day16.part2(input, 100) |> IO.inspect(label: "part2")
                  #                  Day16.run(program, [2]) |> IO.inspect(label: "part2")
  #            IO.inspect(Enum.map(layers, fn l -> Day16.count(l, "0") end))
  #                Day16.part1(layers) |> IO.inspect(label: "step1")
  #                Day16.display(layers, 25, 6)

  _ -> IO.puts("expected --test or input_file")
  #    System.halt(1)

end

