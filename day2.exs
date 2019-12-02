#! /usr/bin/env elixir
defmodule Day2 do

  def init(raw) do
    raw
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
  end

  def run(input,noun, verb) do
    input
    |> List.replace_at(1, noun)
    |> List.replace_at(2, verb)
    |> compute(0)
    |> IO.inspect
    |> get(0)
  end

  defp compute(input, pc) do
    op = get(input, pc)
    case op do
      99 -> input
      1 -> output = List.replace_at(input, get(input, pc+3), dbl_get(input, pc+1) + dbl_get(input, pc+2))
        compute(output, pc+4)
      2 -> output = List.replace_at(input, get(input, pc+3), dbl_get(input, pc+1) * dbl_get(input, pc+2))
        compute(output, pc+4)
    end
  end

  defp get([]=_list, _), do: -99999999
  defp get([head|tail]=_list, 0), do: head
  defp get([head|tail]=_list, i), do: get(tail, i-1)

  defp dbl_get(list, index), do: get(list, get(list, index))

end


case System.argv do
  ["--test"] -> ExUnit.start()
    defmodule Day2Test do
      use ExUnit.Case

      test "initial fuel" do
        assert Day2.run(Day2.init("1,0,0,0,99"), 0,0) == 2
      end
    end
  [input_file] -> input = Day2.init(File.read!(input_file))
                  Day2.run(input, 12, 2) |> IO.inspect(label: "step1")
                  try do
                    for n <- 0..99 do
                      for v <- 0..99 do
                        case Day2.run(input, n, v) do
                          19690720 -> throw({n,v})
                          _ -> :ok
                        end
                      end
                    end
                  catch
                      {n,v} -> IO.inspect(100*n + v, label: "step2")
                  end
  _ -> IO.puts("expected --test or input_file")
    System.halt(1)
end
