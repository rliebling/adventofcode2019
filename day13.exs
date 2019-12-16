#! /usr/bin/env elixir
defmodule Day13 do

  @empty 0
  @wall 1
  @block 2
  @paddle 3
  @ball 4
  @score_coords {-1,0} 

  def init(raw) do
    raw
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
  end

  def run(input) do
  # machine = %{memory: input, pc: pc, inputs: input_values, outputs: outputs, rel_base: rel_base, state: state}
    machine = %{memory: input, pc: 0, map: %{}, buf_out: %{}, loc: {0,0}, dir: :up, painted: [], rel_base: 0, state: :x}
    IO.inspect( Stream.iterate(machine, &compute/1)
              |> Enum.reduce_while(nil, fn %{state: :halted} = m, _acc -> {:halt, m}
                %{state: _}, _acc -> {:cont, true}
              end))
  end
  def part1(input) do
    %{map: map} = run(input)
    Map.values(map)
    |> Enum.filter(&(&1 == @block))
    |> Enum.count
    |> IO.inspect(label: "part1")
  end

  def part2([mem0 | rest]) do
    %{painted: painted, map: map} = machine = run( [2 | rest] )
    map[@score_coords] |> IO.inspect(label: "part2")
  end

  def draw_screen(map) do
    map = Map.delete(map, @score_coords)
    {{min_x,_},_} = Enum.min_by(map, fn({{x,_y},_color})->x end)
    {{max_x,_},_} = Enum.max_by(map, fn({{x,_y},_color})->x end)
    {{_, min_y},_} = Enum.min_by(map, fn({{_x,y},_color})->y end)
    {{_, max_y},_} = Enum.max_by(map, fn({{_x,y},_color})->y end)
    IO.inspect {{min_x, max_y}, {max_x, min_y}, label: "screen range"}

    for y<- max_y..min_y do
      x_range = min_x..max_x
      IO.puts( Enum.map(x_range, &paint(Map.get(map, {&1,y}))) |> Enum.join)
    end
  end

  @empty 0
  @wall 1
  @block 2
  @paddle 3
  @ball 4
  def paint(@empty), do: " "
  def paint(@wall), do: "|"
  def paint(@block), do: "#"
  def paint(@paddle), do: "_"
  def paint(@ball), do: "o"

  # machine = %{memory: input, pc: pc, map: map, outputs: outputs, rel_base: rel_base, state: state}
  def compute(%{state: :halted} = machine), do: machine
  def compute(%{state: _} = machine) do
    %{memory: input, pc: pc, map: map, buf_out: buf_out, loc: loc, dir: dir, painted: painted, rel_base: rel_base, state: state} = machine 
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
          inp_value = determine_move(map)
          output = write(input, m1.( machine, pc+1), inp_value)
          draw_screen(map)
          IO.puts "-----------------------------------------------"
          %{machine | memory: output, pc: pc+2 }
      {:output,1, [m1], _f} -> 
          out_value =  m1.(machine, pc+1)
          #IO.puts("OUTPUT: #{out_value}")
          case state do
            :x -> new_buf_out = Map.put(buf_out, :x, out_value)
              %{machine | pc: pc+2, buf_out: new_buf_out, state: :y}
            :y -> new_buf_out = Map.put(buf_out, :y, out_value)
              %{machine | pc: pc+2, buf_out: new_buf_out, state: :type}
            :type -> new_map = Map.put(map, {buf_out[:x], buf_out[:y]}, out_value)
              #IO.puts("buf: #{inspect buf_out} #{paint(out_value)}")
                     %{machine | pc: pc+2, buf_out: %{}, map: new_map, state: :x }
          end

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

  def move({x,y}=_loc, dir) do
    case dir do
      :up -> {x, y+1}
      :right -> {x+1, y}
      :down -> {x, y-1}
      :left -> {x-1, y}
    end
  end
  def turn(dir, out_value) do
    case {dir, out_value} do
      {:up, 1} -> :left
      {:left, 1} -> :down
      {:down, 1} -> :right
      {:right, 1} -> :up
      {:up, 0} -> :right
      {:right, 0} -> :down
      {:down, 0} -> :left
      {:left, 0} -> :up
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

  def ball_and_paddle(map) do
    [{a, a_type}, {b, b_type}]= Enum.filter(map, fn({loc, type}) -> type == @ball || type == @paddle end)
    ball = if a_type==@ball, do: a, else: b
    paddle = if a_type==@paddle, do: a, else: b
    {ball, paddle}
  end
  def determine_move(map) do
    { {ball_x, _}, {paddle_x, _} } = ball_and_paddle(map)
    cond do
      ball_x < paddle_x -> -1
      ball_x == paddle_x -> 0
      paddle_x < ball_x -> 1
    end
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
    defmodule Day13Test do
      use ExUnit.Case

      # test "initial fuel" do
      #     assert Day13.run(Day13.init("1002,4,3,4,33"), 0,0) == 2
      #   end
      #      test "part2 " do
      #        assert Day13.run(Day13.init("3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99"), 8,0) == 2
      #        #assert Day13.run(Day13.init("3,12,6,12,15,1,13,14,13,4,13,99,-1,0,1,9"), 0,0) == 2
      #        #assert Day13.run(Day13.init("3,3,1105,-1,9,1101,0,0,12,4,12,99,1"), 0,0) == 2
      #        #assert Day13.run(Day13.init("5,9,10,104,0,99,104,1,99,1,6"), 0,0) == 2
      #      end

      test "simple" do
        source = "109,1,204,-1,1001,100,1,100,1008,100,16,101,1006,101,0,99"
        program = Day13.init(source)
        #machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day13.run(program, [])
        assert outputs == program
      end

      test "produce 16digit#" do
        source = "1102,34915192,34915192,7,4,7,99,0"
        program = Day13.init(source)
        #machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day13.run(program, [])
        assert 1_000_000_000_000_000 <= hd(outputs) && hd(outputs) < 10_000_000_000_000_000
      end

      test "my test of 203 " do
        source = "1102,34915192,34915192,7,4,7,99,0"
        program = Day13.init(source)
        #machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day13.run(program, [])
        assert 1_000_000_000_000_000 <= hd(outputs) && hd(outputs) < 10_000_000_000_000_000
      end
    end


  [input_file] -> program = Day13.init(File.read!(input_file))
                  Day13.part1(program) |> IO.inspect(label: "part1")
                  Day13.part2(program) |> IO.inspect(label: "part2")
                  #                  Day13.run(program, [2]) |> IO.inspect(label: "part2")
  #            IO.inspect(Enum.map(layers, fn l -> Day13.count(l, "0") end))
  #                Day13.part1(layers) |> IO.inspect(label: "step1")
  #                Day13.display(layers, 25, 6)

  _ -> IO.puts("expected --test or input_file")
  #    System.halt(1)
end
