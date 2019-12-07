#! /usr/bin/env elixir
defmodule Day5 do
  def init(raw) do
    raw
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
  end

  def run(input,noun, verb) do
    input
    #    |> List.replace_at(1, noun)
    #|> List.replace_at(2, verb)
    |> compute(0)
    |> IO.inspect
    |> get(0)
  end

  defp compute(input, pc) do
     IO.inspect({input, pc})
    op = get(input, pc)
    case parse_op(op) do
      {:halt,_,_,_} -> IO.inspect(input)
      {:add,3, [m1, m2, m3], f} -> output = List.replace_at(input, get(input, pc+3), m1.(input, pc+1) + m2.(input, pc+2))
        compute(output, pc+4)
      {:mult,3, [m1, m2, m3], f} -> output = List.replace_at(input, get(input, pc+3), m1.(input, pc+1) * m2.(input, pc+2))
        compute(output, pc+4)
      {:input,1, [m1], f} -> IO.puts("input a value")
          inp_value = IO.read(:stdio, :line) |> String.trim |> String.to_integer
          output = List.replace_at(input, get(input, pc+1), inp_value) # ignore mode since writing
          compute(output, pc+2)
      {:output,1, [m1], f} -> 
          out_value =  m1.(input, pc+1)
          IO.puts("OUTPUT: #{out_value}")
          compute(input, pc+2)

      {:jump_if_true, 2, [m1, m2], f} -> IO.inspect( m1.(input, pc+1),label: "jit");case m1.(input, pc+1) != 0 do
        true -> compute(input, m2.(input, pc+2))
        false -> compute(input, pc+3) # skip!
      end
      {:jump_if_false, 2, [m1, m2], f} -> case m1.(input, pc+1) != 0 do
        true -> compute(input, pc+3) # skip!
        false -> compute(input, m2.(input, pc+2))
      end
      {:less_than, 3, [m1, m2, m3], f} -> result = if m1.(input, pc+1) < m2.(input, pc+2), do: 1, else: 0
                                          output = List.replace_at(input, get(input, pc+3), result)
                                          compute(output, pc+4)
      {:equals, 3, [m1, m2, m3], f} -> result = if m1.(input, pc+1) == m2.(input, pc+2), do: 1, else: 0
                                       output = List.replace_at(input, get(input, pc+3), result)
                                       compute(output, pc+4)
    end
  end

  # {op, arity, modes, fn}
  def parse_op(instr) do
    {op,arity} = case rem(instr, 100) do
      1 -> {:add, 3}
      2-> {:mult, 3}
      3-> {:input, 1}
      4 -> {:output, 1}
      5-> {:jump_if_true, 2}
      6-> {:jump_if_false, 2}
      7-> {:less_than, 3}
      8-> {:equals, 3}
      99 -> {:halt, 1} # so modes doesn't get range 1..0 which has count 2!!!!

      _ -> IO.inspect(instr)
    end
    modes = Enum.reduce(1..arity, [], fn i, acc -> [div(instr, power(10,i+1))|> rem(10) | acc] end)
            |> Enum.reverse()
            |> Enum.map(fn m -> if m==1, do: &immediate/2, else: &dbl_get/2 end )
    {op, arity, modes, nil}
  end

  def power(base, exp), do: :math.pow(base, exp)|> round


  defp get([]=_list, _), do: -99999999
  defp get([head|tail]=_list, 0), do: head
  defp get([head|tail]=_list, i), do: get(tail, i-1)

  defp dbl_get(list, operand), do: get(list, get(list, operand))
  def immediate(list, operand), do: get(list, operand)

end


case System.argv do
  ["--test"] -> ExUnit.start()
    defmodule Day5Test do
      use ExUnit.Case

    # test "initial fuel" do
    #     assert Day5.run(Day5.init("1002,4,3,4,33"), 0,0) == 2
    #   end
      test "part2 " do
    assert Day5.run(Day5.init("3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99"), 0,0) == 2
    #assert Day5.run(Day5.init("3,12,6,12,15,1,13,14,13,4,13,99,-1,0,1,9"), 0,0) == 2
    #assert Day5.run(Day5.init("3,3,1105,-1,9,1101,0,0,12,4,12,99,1"), 0,0) == 2
    #assert Day5.run(Day5.init("5,9,10,104,0,99,104,1,99,1,6"), 0,0) == 2
      end
    end
  [input_file] -> input = Day5.init(File.read!(input_file))
                  Day5.run(input, 12, 2) |> IO.inspect(label: "step1")

  _ -> IO.puts("expected --test or input_file")
  #    System.halt(1)
end
