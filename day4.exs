#! /usr/bin/env elixir
defmodule Day4 do

  def count_candidates(min, max) do
    (min..max)
    |> Enum.count(fn p -> is_eligible(p) end)
  end

  def is_eligible(p) do
    digits = Integer.to_string(p) |> String.graphemes
    cond do
      ! has_consecutive_digits(digits) -> false
      ! has_exactly_two_consecutive_digits(digits) -> false
      has_decreasing_digits(digits) -> false
      true -> true
    end
  end

  def has_consecutive_digits(digits) do
    true == Enum.reduce_while(digits, "", fn d, prev -> if d==prev, do: {:halt, true }, else: {:cont, d} end)
  end

  def has_exactly_two_consecutive_digits(digits) do
    (["X"] ++ digits ++ ["X"])
    |> Enum.chunk_every(4, 1, :discard)
    |> Enum.find(fn [a,b,c,d]-> a != b && b==c && c != d end)
  end

  def has_decreasing_digits(digits) do
    true == Enum.reduce_while(digits, "", fn d, prev -> if prev>d, do: {:halt, true}, else: {:cont, d} end)
  end

  def has_three_consecutive(digits) do
    digits
    |> Enum.chunk_every(3,1, :discard)
    |> Enum.find(fn [a,b,c] -> a==b && b==c end)
  end

end

Day4.count_candidates( 152085,670283) |> IO.puts
# System.halt(0)
# 
# case System.argv do
#   ["--test"] -> ExUnit.start()
#     defmodule Day4Test do
#       use ExUnit.Case
# 
#       test "initial fuel" do
#         input = Day4.init("R75,D30,R83,U83,L12,D49,R71,U7,L72\nU62,R66,U55,R34,D71,R55,D58,R83")
#         assert Day4.intersections(input)|> Day3.nearest(&Day3.time_min/1) == 610
#       end
#     end
# 
#   [input_file] -> input = Day3.init(File.read!(input_file))
# 
#   _ -> IO.puts("expected --test or input_file")
#     System.halt(1)
# end
