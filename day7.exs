#! /usr/bin/env elixir
defmodule Day7 do
  def optimize(program) do
    perms = permutations([0,1,2,3,4])
    perms |> Enum.reduce(-999, fn perm, max_thrust -> max(run_sequence(perm, program), max_thrust) end)
  end

  def run_sequence(perm, program) do
    perm
    |> IO.inspect(label: "run_sequence")
    |> Enum.reduce(0, fn phase,prev_input -> run(program, phase, prev_input) end)
  end

  def permutations(list) do
    do_permutations(list) |> Enum.chunk_every(length(list))
  end

  def do_permutations(list, acc \\ [] )
  def do_permutations([], acc), do: acc
  def do_permutations(list, acc) do
    list
    |> Enum.flat_map(fn e -> do_permutations(List.delete(list, e), [e | acc]) end)
  end

  def init(raw) do
    raw
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
  end

  def run(input,phase, prev_output) do
    IO.inspect(phase, label: "phase")
    IO.inspect(prev_output, label: "prev_output")

    input
    #    |> List.replace_at(1, noun)
    #|> List.replace_at(2, verb)
    |> compute(0, [phase, prev_output])
    |> IO.inspect(label: "run")
  end

  defp compute(input, pc, input_values, out_value \\ nil) do
    # IO.inspect({input, pc})
    op = get(input, pc)
    case parse_op(op) do
      {:halt,_,_,_} -> IO.inspect(out_value, label: "output/halt:")
      {:add,3, [m1, m2, m3], f} -> output = List.replace_at(input, get(input, pc+3), m1.(input, pc+1) + m2.(input, pc+2))
        compute(output, pc+4, input_values, out_value)
      {:mult,3, [m1, m2, m3], f} -> output = List.replace_at(input, get(input, pc+3), m1.(input, pc+1) * m2.(input, pc+2))
        compute(output, pc+4, input_values, out_value)
      {:input,1, [m1], f} -> #IO.puts("input a value")
          #inp_value = IO.read(:stdio, :line) |> String.trim |> String.to_integer
          [inp_value | rest_of_input_values] = input_values
          output = List.replace_at(input, get(input, pc+1), inp_value) # ignore mode since writing
          compute(output, pc+2, rest_of_input_values, out_value)
      {:output,1, [m1], f} -> 
          out_value =  m1.(input, pc+1)
          IO.puts("OUTPUT: #{out_value}")
          compute(input, pc+2, input_values, out_value)

      {:jump_if_true, 2, [m1, m2], f} -> IO.inspect( m1.(input, pc+1),label: "jit");case m1.(input, pc+1) != 0 do
        true -> compute(input, m2.(input, pc+2), input_values, out_value)
        false -> compute(input, pc+3, input_values, out_value) # skip!
      end
      {:jump_if_false, 2, [m1, m2], f} -> case m1.(input, pc+1) != 0 do
        true -> compute(input, pc+3, input_values) # skip!
        false -> compute(input, m2.(input, pc+2), input_values, out_value)
      end
      {:less_than, 3, [m1, m2, m3], f} -> result = if m1.(input, pc+1) < m2.(input, pc+2), do: 1, else: 0
                                          output = List.replace_at(input, get(input, pc+3), result)
                                          compute(output, pc+4, input_values, out_value)
      {:equals, 3, [m1, m2, m3], f} -> result = if m1.(input, pc+1) == m2.(input, pc+2), do: 1, else: 0
                                       output = List.replace_at(input, get(input, pc+3), result)
                                       compute(output, pc+4, input_values, out_value)
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
    defmodule Day7Test do
      use ExUnit.Case

    # test "initial fuel" do
    #     assert Day7.run(Day7.init("1002,4,3,4,33"), 0,0) == 2
    #   end
    #      test "part2 " do
    #        assert Day7.run(Day7.init("3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99"), 8,0) == 2
    #        #assert Day7.run(Day7.init("3,12,6,12,15,1,13,14,13,4,13,99,-1,0,1,9"), 0,0) == 2
    #        #assert Day7.run(Day7.init("3,3,1105,-1,9,1101,0,0,12,4,12,99,1"), 0,0) == 2
    #        #assert Day7.run(Day7.init("5,9,10,104,0,99,104,1,99,1,6"), 0,0) == 2
    #      end

    test "day7 part1" do
      program = Day7.init("3,15,3,16,1002,16,10,16,1,16,15,15,4,15,99,0,0")
      assert Day7.optimize(program) == 43210
    end
    test "day7 part1b" do
      program = Day7.init("3,23,3,24,1002,24,10,24,1002,23,-1,23,101,5,23,23,1,24,23,23,4,23,99,0,0")
      assert Day7.optimize(program) == 54321
    end
    test "day7 part1c" do
      program = Day7.init("3,31,3,32,1002,32,10,32,1001,31,-2,31,1007,31,0,33,1002,33,7,33,1,33,31,31,1,32,31,31,4,31,99,0,0,0")
      assert Day7.optimize(program) ==  65210
    end
  end

  [input_file] -> input = Day7.init(File.read!(input_file))
                  Day7.optimize(input) |> IO.inspect(label: "step1")

  _ -> IO.puts("expected --test or input_file")
  #    System.halt(1)
end
