#! /usr/bin/env elixir
defmodule Day9 do

  #  def build_amp(program, phase, inp_value) do
  #    {:output, out_val, amp}=compute(program, 0, [phase, inp_value])
  #    {amp, out_val}
  #  end
  #  def run_sequence2(perm, program) do
  #    {amps, output} = Enum.map_reduce(perm, 0, fn phase, acc -> build_amp(program, phase, acc) end)
  #    run_loop(amps, output)
  #  end
  #
  #  def run_loop([nil | _rest], input), do: input
  #  def run_loop(amps, input) do
  #    {new_amps, e_output} = amps
  #              |> Enum.map_reduce(input, fn amp, prev_output -> result = amp.(prev_output)
  #                  case result do
  #                    {:output, out_value, amp_update} -> {amp_update, out_value}
  #                    {:halt, out_value} -> {nil, out_value}
  #                  end
  #                end)
  #    run_loop(new_amps, e_output)
  #  end

  def init(raw) do
    raw
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
  end

  def run(input, input_values) do
  # machine = %{memory: input, pc: pc, inputs: input_values, outputs: outputs, rel_base: rel_base, state: state}
    machine = %{memory: input, pc: 0, inputs: input_values, outputs: [], rel_base: 0, state: :ready}
    outputs = Stream.iterate(machine, &compute/1)
              |> Enum.reduce_while(nil, fn %{state: :halted, outputs: outputs}, _acc -> {:halt, outputs}
                %{state: :ready}, _acc -> {:cont, true}
              end)
    IO.inspect(outputs, label: "outputs")
    outputs
  end

  # machine = %{memory: input, pc: pc, inputs: input_values, outputs: outputs, rel_base: rel_base, state: state}
  def compute(%{state: :halted} = machine), do: machine
  def compute(%{state: :ready} = machine) do
    %{memory: input, pc: pc, inputs: input_values, outputs: outputs, rel_base: rel_base, state: state} = machine 
    op = get(machine, pc)
    {mnemonic, arity, _, _} = parsed_op = parse_op(op)
    #IO.puts("[#{pc}] #{op} #{mnemonic} #{Enum.map(1..arity, &get(machine, pc+&1))|> Enum.join(",")} pre_rel=#{rel_base}")
    case parsed_op do
      {:halt,_,_,_} -> %{machine | state: :halted}
      {:add,3, [m1, m2, m3], _f} -> output = write(input, m3.( machine, pc+3), m1.(machine, pc+1) + m2.(machine, pc+2))
        %{machine | memory: output, pc: pc+4}
      {:mult,3, [m1, m2, m3], _f} -> output = write(input, m3.( machine, pc+3), m1.(machine, pc+1) * m2.(machine, pc+2))
        %{machine | memory: output, pc: pc+4}
      {:input,1, [m1], _f} -> 
          [inp_value | rest_of_input_values] = input_values
          output = write(input, m1.( machine, pc+1), inp_value)
          %{machine | memory: output, pc: pc+2, inputs: rest_of_input_values}
      {:output,1, [m1], _f} -> 
          out_value =  m1.(machine, pc+1)
          #IO.puts("OUTPUT: #{out_value}")
          #compute(input, pc+2, input_values, out_value)
          # {:output, out_value, fn inp_value -> compute(input, pc+2, [inp_value]) end} #{:output, out_value, input, pc+2}
          %{machine | memory: input, pc: pc+2, outputs: outputs ++ [out_value]}

      {:jump_if_true, 2, [m1, m2], _f} -> case m1.(machine, pc+1) != 0 do
        true -> %{machine | pc: m2.(machine, pc+2)}
        false -> %{machine | pc: pc+3}
      end
      {:jump_if_false, 2, [m1, m2], _f} -> case m1.(machine, pc+1) != 0 do
        true -> %{machine | pc: pc+3}
        false -> %{machine | pc: m2.(machine, pc+2)}
      end
      {:less_than, 3, [m1, m2, m3], _f} -> result = if m1.(machine, pc+1) < m2.(machine, pc+2), do: 1, else: 0
                                          output = write(input, m3.( machine, pc+3), result)
                                          %{machine | memory: output, pc: pc+4}
      {:equals, 3, [m1, m2, m3], _f} -> result = if m1.(machine, pc+1) == m2.(machine, pc+2), do: 1, else: 0
                                       output = write(input, m3.( machine, pc+3), result)
                                       %{machine | memory: output, pc: pc+4}
      {:adj_relative_base, 1, [m1], _f} -> %{machine | pc: pc+2, rel_base: rel_base + m1.(machine, pc+1)}
    end
  end

  # {op, arity, modes, fn}
  def parse_op(instr) do
    {op,arity, does_write?} = case rem(instr, 100) do
      1 -> {:add, 3, :write}
      2-> {:mult, 3, :write}
      3-> {:input, 1, :write}
      4 -> {:output, 1, :no_write}
      5-> {:jump_if_true, 2, :no_write}
      6-> {:jump_if_false, 2, :no_write}
      7-> {:less_than, 3, :write}
      8-> {:equals, 3, :write}
      9-> {:adj_relative_base, 1, :no_write}
      99 -> {:halt, 0, :no_write} # so modes doesn't get range 1..0 which has count 2!!!!

      _ -> IO.inspect(instr)
    end
    modes = Enum.reduce(1..arity, [], fn i, acc -> [div(instr, power(10,i+1))|> rem(10) | acc] end)
            |> Enum.reverse()
            |> Enum.with_index
            |> Enum.map(fn 
              {0,index} -> if does_write?==:write && index==arity-1, do: &positional_write/2, else: &positional/2
              {1,index} -> &immediate/2
              {2,index} -> if does_write?==:write && index==arity-1, do: &relative_write/2, else: &relative/2
              _ -> IO.puts("NO mode found for #{instr}"); nil
            end )
    {op, arity, modes, nil }
    #    rel = &relative/2
    #    case {op, modes} do
    #      {:input, [rel]} -> {op, arity, [&relative_write/2], nil} 
    #      #      {:output, [rel]} -> {op, arity, [&relative_write/2], nil} 
    #      {:less_than, [m1, m2, rel]} -> {op, arity, [m1, m2, &relative_write/2], nil}
    #      {:equals, [m1, m2, rel]} -> {op, arity, [m1, m2, &relative_write/2], nil}
    #        _ -> {op, arity, modes, nil}
    #    end
  end

  def power(base, exp), do: :math.pow(base, exp)|> round


  def write(memory, addr, value) when addr < length(memory) do
    #IO.puts("WRITE1: #{addr} #{value}")
    List.replace_at(memory, addr, value)
  end
  def write(memory, addr, value) do
    #IO.puts("WRITE2: #{addr} #{value}")
    memory ++ List.duplicate(0, addr - length(memory)) ++ [value]
  end

  defp get(%{memory: []}, _), do: 0
  defp get(%{memory: [head | _tail]}, 0), do: head
  defp get(%{memory: [_head | tail]}, i), do: get(%{memory: tail}, i-1)

  defp positional(machine, operand), do: get(machine, get(machine, operand))
  defp positional_write(machine, operand), do: get(machine, operand)

  def immediate(machine, operand), do: get(machine, operand)

  def relative(%{memory: mem, rel_base: rel_base}=machine, operand) do
    get(machine, rel_base + get(machine, operand))
  end
  def relative_write(%{memory: mem, rel_base: rel_base}=machine, operand) do
    rel_base + get(machine, operand)
  end


end


case System.argv do
  ["--test"] -> ExUnit.start()
    defmodule Day9Test do
      use ExUnit.Case

      # test "initial fuel" do
      #     assert Day9.run(Day9.init("1002,4,3,4,33"), 0,0) == 2
      #   end
      #      test "part2 " do
      #        assert Day9.run(Day9.init("3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99"), 8,0) == 2
      #        #assert Day9.run(Day9.init("3,12,6,12,15,1,13,14,13,4,13,99,-1,0,1,9"), 0,0) == 2
      #        #assert Day9.run(Day9.init("3,3,1105,-1,9,1101,0,0,12,4,12,99,1"), 0,0) == 2
      #        #assert Day9.run(Day9.init("5,9,10,104,0,99,104,1,99,1,6"), 0,0) == 2
      #      end

      test "simple" do
        source = "109,1,204,-1,1001,100,1,100,1008,100,16,101,1006,101,0,99"
        program = Day9.init(source)
        #machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day9.run(program, [])
        assert outputs == program
      end

      test "produce 16digit#" do
        source = "1102,34915192,34915192,7,4,7,99,0"
        program = Day9.init(source)
        #machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day9.run(program, [])
        assert 1_000_000_000_000_000 <= hd(outputs) && hd(outputs) < 10_000_000_000_000_000
      end

      test "my test of 203 " do
        source = "1102,34915192,34915192,7,4,7,99,0"
        program = Day9.init(source)
        #machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day9.run(program, [])
        assert 1_000_000_000_000_000 <= hd(outputs) && hd(outputs) < 10_000_000_000_000_000
      end
    end


  [input_file] -> program = Day9.init(File.read!(input_file))
                  Day9.run(program, [1]) |> IO.inspect(label: "part1")
                  Day9.run(program, [2]) |> IO.inspect(label: "part2")
  #            IO.inspect(Enum.map(layers, fn l -> Day9.count(l, "0") end))
  #                Day9.part1(layers) |> IO.inspect(label: "step1")
  #                Day9.display(layers, 25, 6)

  _ -> IO.puts("expected --test or input_file")
  #    System.halt(1)
end
