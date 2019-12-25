#! /usr/bin/env elixir
defmodule Day21 do
  defmodule Mapper do
    use Agent

    defstruct instrs: [], output: []

    def start_link(instrs) do
      Agent.start_link(fn -> %Mapper{instrs: to_charlist(instrs)} end, name: __MODULE__)
    end

    def reset_instrs(instrs) do
      Agent.update(__MODULE__, fn s -> %Mapper{instrs: to_charlist(instrs)} end)
    end

    def next do
      f = fn %Mapper{instrs: [h | tail]} = s -> {h, %Mapper{s | instrs: tail}} end

      Agent.get_and_update(__MODULE__, f)
    end

    def output(val) do
      updater = fn %Mapper{} = s ->
        %Mapper{s | output: [val | s.output]}
      end

      Agent.update(__MODULE__, updater)
    end

    def puts do
      Agent.get(__MODULE__, & &1.output)
      |> IO.inspect(label: "raw output")
      |> Enum.reject(&(&1 > 127))
      |> to_string
      |> String.reverse()
      |> IO.puts()
    end
  end

  def init(raw) do
    raw
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
  end

  @instrs """
  NOT A J
  NOT B T
  OR T J
  NOT C T
  OR T J
  AND D J
  WALK
  """
  def part1(input, instrs \\ @instrs) do
    Mapper.start_link(instrs)

    initial_state = %{
      memory: input,
      pc: 0,
      map: %{},
      stdout: &Mapper.output/1,
      guide: &Mapper.next/0,
      loc: {0, 0},
      dir: {1, 0},
      rel_base: 0,
      state: :ready
    }

    final_m =
      Stream.iterate(initial_state, &compute(&1))
      |> Enum.reduce_while(nil, fn m, _acc ->
        case m[:state] do
          :ready -> {:cont, m}
          :halted -> {:halt, m}
          _ -> {:cont, m}
        end
      end)

    Mapper.puts()
    # IO.inspect(Mapper.count_affected(), label: "part1 count")
  end

  def part2(input) do
    instrs2 = """
    OR I T
    AND E T
    OR H T
    AND D T
    OR G T
    AND C T
    OR F T
    AND B T
    OR I J
    OR F J
    AND E J
    OR T J
    AND A J
    NOT J J
    RUN
    """

    instrs = """
    OR C T
    AND B T
    AND A T
    NOT T T
    AND H T
    AND D T
    OR B J
    OR E J
    NOT J J
    OR T J
    NOT J J
    AND A J
    NOT J J
    RUN
    """

    # if NOT A OR (NOT B & NOT E) OR (D & H and NOT (A & B & C))
    # OR C T
    # AND B T
    # AND A T
    # NOT T T
    # AND H T
    # AND D T
    # OR B J
    # OR E J
    # NOT J J
    # OR T J
    # NOT J J
    # AND A J
    # NOT J J
    # 
    #
    # not p or q -> NOT( p and NOT q)
    #
    #
    # if D & H
    #  or DEI
    #  or DEF
    #
    #  (D & H & !E & !F & !G) | (D & E & I) | (D & E & F)
    #  D & ( (H & !E & !F & !G)| (E & I) | (E & F)
    #  D & ( H | (E & (I | F) ) )
    #  OR F T
    #  OR I T
    #  AND E T
    #  OR H T
    #  AND D T
    #  OR T J
    #
    #     J   J X
    #   #####.#.#.#..####
    #      ABCDEFGHI
    #   ABDFH
    #
    #  #####.##.######## 
    #   ABCDEFGHI
    #   ABCDFGI
    #      J   x
    #   #####.#.#.#..####
    #       ABCDEFGHI
    #   ACEG
    # 5  BDFI
    #
    # !A | (!B & !E) | (!B & !F & !I) | (!C & !E & !F | !C & !F
    #  !A
    #  !B & (!E | (!F & !I) )
    #  !C & ( ( (!E | (!F & !I)) )  & (!F )
    #
    #  !A
    #  !B AND NOT WAIT_1 == NOT (B OR WAIT_1)
    #  !C AND NOT WAIT_1 AND NOT WAIT 2 == NOT (C OR WAIT_1 OR WAIT_2)
    #  !D AND NOT WAIT_1 AND NOT WAIT 2 and NOT WAIT 3
    #  !E AND NOT WAIT 1, 2, 3, 4
    #  !F AND NOT WAIT 1, 2, 3, 4, 5
    #
    #  NOT (A & ( B OR WAIT1) & (C OR WAIT1 OR WAIT2) & (D OR WAIT1 OR WAIT2 or WAIT3) )
    #  NOT ( WAIT1 OR ( B  & (WAIT2 OR (C & (WAIT3 OR (D & (WAIT4 OR (E & WAIT5)) ) ) )
    #
    # NOT WAIT5 = !I
    # NOT WAIT4 = !H
    # NOT WAIT3 = !G
    # NOT WAIT2 = !F
    # NOT WAIT1 = !E | (!F & !I) = NOT (E AND (F | I))
    #
    # OR I T
    # AND E T
    # OR H T
    # AND D T
    # OR G T
    # AND C T
    # OR F T
    # AND B T
    #
    # OR I J
    # OR F J
    # AND E J
    #
    # OR T J
    # AND A J
    #
    # NOT J J
    #
    # 
    # NOT A OR (NOT B AND NOT E) oR (NOT C AND NOT E AND NOT F) OR (NOT D AND NOT E AND NOT F AND NOT G) OR (NOT E AND NOT F AND NOT G AND NOT H AND NOT I)
    # NOT A OR NOT(B OR E) OR NOT(C OR E OR F) OR NOT(D OR E OR F OR G) OR NOT(E OR F OR G OR H OR I)
    # NOT (A AND (B OR E) AND (C OR E OR F) AND (D OR E OR F OR G) AND (E OR F OR G OR H OR I)) - NOT P OR NOT Q == NOT(P AND Q)
    # NOT( A AND (E OR (B AND (C OR F) AND (D OR F OR G) AND (F Or G Or H OR I))))
    # NOT( A AND (E OR (B AND (F OR (C  AND (D OR G) AND (G OR H OR I))))))
    # NOT( A AND (E OR (B AND (F OR (C  AND (G OR (D AND H AND I)))))))
    #
    #
    # AND A T
    # NOT T J
    #
    # AND C T -- if T is false J is already true so won't matter
    # AND E T
    # AND F T
    # NOT 
    #
    # jump if a
    Mapper.reset_instrs(instrs)

    initial_state = %{
      memory: input,
      pc: 0,
      map: %{},
      stdout: &Mapper.output/1,
      guide: &Mapper.next/0,
      loc: {0, 0},
      dir: {1, 0},
      rel_base: 0,
      state: :ready
    }

    final_m =
      Stream.iterate(initial_state, &compute(&1))
      |> Enum.reduce_while(nil, fn m, _acc ->
        case m[:state] do
          :ready -> {:cont, m}
          :halted -> {:halt, m}
          _ -> {:cont, m}
        end
      end)

    Mapper.puts()
  end

  #######################################
  # IntCode Computer
  # #####################################

  # machine = %{memory: input, pc: pc, map: map, outputs: outputs, rel_base: rel_base, state: state}
  def compute(%{state: :halted} = machine), do: machine

  def compute(%{state: _} = machine) do
    %{
      memory: input,
      pc: pc,
      stdout: stdout,
      guide: guide,
      loc: loc,
      dir: dir,
      rel_base: rel_base,
      state: state
    } = machine

    op = get(machine, pc)
    {mnemonic, arity, _, _} = parsed_op = parse_op(op)

    # IO.puts(
    #   "[#{pc}] #{op} #{mnemonic} #{Enum.map(1..arity, &get(machine, pc + &1)) |> Enum.join(",")} pre_rel=#{
    #     rel_base
    #   }"
    # )

    case parsed_op do
      {:halt, _, _, _} ->
        %{machine | state: :halted}

      {:add, 3, [m1, m2, m3], _f} ->
        output = write(input, m3.(machine, pc + 3), m1.(machine, pc + 1) + m2.(machine, pc + 2))
        %{machine | memory: output, pc: pc + 4}

      {:mult, 3, [m1, m2, m3], _f} ->
        output = write(input, m3.(machine, pc + 3), m1.(machine, pc + 1) * m2.(machine, pc + 2))
        %{machine | memory: output, pc: pc + 4}

      {:input, 1, [m1], _f} ->
        # IO.puts("Moving from #{inspect loc}")
        inp_value = guide.()
        output = write(input, m1.(machine, pc + 1), inp_value)
        %{machine | memory: output, pc: pc + 2}

      {:output, 1, [m1], _f} ->
        out_value = m1.(machine, pc + 1)
        stdout.(out_value)
        %{machine | pc: pc + 2}

      {:jump_if_true, 2, [m1, m2], _f} ->
        case m1.(machine, pc + 1) != 0 do
          true -> %{machine | pc: m2.(machine, pc + 2)}
          false -> %{machine | pc: pc + 3}
        end

      {:jump_if_false, 2, [m1, m2], _f} ->
        case m1.(machine, pc + 1) != 0 do
          true -> %{machine | pc: pc + 3}
          false -> %{machine | pc: m2.(machine, pc + 2)}
        end

      {:less_than, 3, [m1, m2, m3], _f} ->
        result = if m1.(machine, pc + 1) < m2.(machine, pc + 2), do: 1, else: 0
        output = write(input, m3.(machine, pc + 3), result)
        %{machine | memory: output, pc: pc + 4}

      {:equals, 3, [m1, m2, m3], _f} ->
        result = if m1.(machine, pc + 1) == m2.(machine, pc + 2), do: 1, else: 0
        output = write(input, m3.(machine, pc + 3), result)
        %{machine | memory: output, pc: pc + 4}

      {:adj_relative_base, 1, [m1], _f} ->
        %{machine | pc: pc + 2, rel_base: rel_base + m1.(machine, pc + 1)}
    end
  end

  def goal_guide(map, loc, goal) do
    visited = fn d -> Map.has_key?(map, move1(loc, d)) end
    unvisited_dirs = @possible_dirs |> Enum.reject(visited)

    case unvisited_dirs do
      [] -> :abort
      choices -> Enum.min_by(choices, fn d -> distance(goal, move1(loc, d)) end)
    end
  end

  def distance({x1, y1}, {x2, y2}), do: abs(x2 - x1) + abs(y2 - y1)

  def choose_dir(map, loc) do
    visited = fn d -> Map.has_key?(map, move1(loc, d)) end
    unvisited_dirs = @possible_dirs |> Enum.reject(visited)

    case unvisited_dirs do
      [] ->
        walled = fn d -> Map.get(map, move1(loc, d)) == @wall end
        @possible_dirs |> Enum.reject(walled) |> Enum.random()

      choices ->
        Enum.random(choices)
    end
  end

  def determine_move({1, 0}), do: 4
  def determine_move({-1, 0}), do: 3
  def determine_move({0, 1}), do: 2
  def determine_move({0, -1}), do: 1

  def move1({x, y} = _loc, {dx, dy} = _dir) do
    {x + dx, y + dy}
  end

  # {op, arity, modes, fn}
  def parse_op(instr) do
    {op, arity, does_write?} =
      case rem(instr, 100) do
        1 ->
          {:add, 3, :write}

        2 ->
          {:mult, 3, :write}

        3 ->
          {:input, 1, :write}

        4 ->
          {:output, 1, :no_write}

        5 ->
          {:jump_if_true, 2, :no_write}

        6 ->
          {:jump_if_false, 2, :no_write}

        7 ->
          {:less_than, 3, :write}

        8 ->
          {:equals, 3, :write}

        9 ->
          {:adj_relative_base, 1, :no_write}

        # so modes doesn't get range 1..0 which has count 2!!!!
        # use arity 1 for instruction 99 so the modes calculation doesn't find an error
        99 ->
          {:halt, 1, :no_write}

        _ ->
          IO.inspect(instr, label: "unmatched instr%100")
          {:halt, 1, :no_write}
      end

    modes =
      Enum.reduce(1..arity, [], fn i, acc -> [div(instr, power(10, i + 1)) |> rem(10) | acc] end)
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.map(fn
        {0, index} ->
          if does_write? == :write && index == arity - 1,
            do: &positional_write/2,
            else: &positional/2

        {1, index} ->
          &immediate/2

        {2, index} ->
          if does_write? == :write && index == arity - 1, do: &relative_write/2, else: &relative/2

        x ->
          IO.puts("NO mode found for #{instr} #{inspect(x)}")
          nil
      end)

    {op, arity, modes, nil}
    #    rel = &relative/2
    #    case {op, modes} do
    #      {:input, [rel]} -> {op, arity, [&relative_write/2], nil} 
    #      #      {:output, [rel]} -> {op, arity, [&relative_write/2], nil} 
    #      {:less_than, [m1, m2, rel]} -> {op, arity, [m1, m2, &relative_write/2], nil}
    #      {:equals, [m1, m2, rel]} -> {op, arity, [m1, m2, &relative_write/2], nil}
    #        _ -> {op, arity, modes, nil}
    #    end
  end

  def power(base, exp), do: :math.pow(base, exp) |> round

  def write(memory, addr, value) when addr < length(memory) do
    # IO.puts("WRITE1: #{addr} #{value}")
    List.replace_at(memory, addr, value)
  end

  def write(memory, addr, value) do
    # IO.puts("WRITE2: #{addr} #{value}")
    memory ++ List.duplicate(0, addr - length(memory)) ++ [value]
  end

  defp get(%{memory: []}, _), do: 0
  defp get(%{memory: [head | _tail]}, 0), do: head
  defp get(%{memory: [_head | tail]}, i), do: get(%{memory: tail}, i - 1)

  defp positional(machine, operand), do: get(machine, get(machine, operand))
  defp positional_write(machine, operand), do: get(machine, operand)

  def immediate(machine, operand), do: get(machine, operand)

  def relative(%{memory: mem, rel_base: rel_base} = machine, operand) do
    get(machine, rel_base + get(machine, operand))
  end

  def relative_write(%{memory: mem, rel_base: rel_base} = machine, operand) do
    rel_base + get(machine, operand)
  end
end

case System.argv() do
  ["--test"] ->
    ExUnit.start()

    defmodule Day21Test do
      use ExUnit.Case

      # test "initial fuel" do
      #     assert Day21.run(Day21.init("1002,4,3,4,33"), 0,0) == 2
      #   end
      #      test "part2 " do
      #        assert Day21.run(Day21.init("3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99"), 8,0) == 2
      #        #assert Day21.run(Day21.init("3,12,6,12,15,1,13,14,13,4,13,99,-1,0,1,9"), 0,0) == 2
      #        #assert Day21.run(Day21.init("3,3,1105,-1,9,1101,0,0,12,4,12,99,1"), 0,0) == 2
      #        #assert Day21.run(Day21.init("5,9,10,104,0,99,104,1,99,1,6"), 0,0) == 2
      #      end

      test "simple" do
        source = "109,1,204,-1,1001,100,1,100,1008,100,16,101,1006,101,0,99"
        program = Day21.init(source)
        # machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day21.run(program, [])
        assert outputs == program
      end

      test "produce 16digit#" do
        source = "1102,34915192,34915192,7,4,7,99,0"
        program = Day21.init(source)
        # machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day21.run(program, [])
        assert 1_000_000_000_000_000 <= hd(outputs) && hd(outputs) < 10_000_000_000_000_000
      end

      test "my test of 203 " do
        source = "1102,34915192,34915192,7,4,7,99,0"
        program = Day21.init(source)
        # machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day21.run(program, [])
        assert 1_000_000_000_000_000 <= hd(outputs) && hd(outputs) < 10_000_000_000_000_000
      end
    end

  [input_file] ->
    program = Day21.init(File.read!(input_file))
    p1 = Day21.part1(program) |> IO.inspect(label: "part1")

    p = Day21.part2(program) |> IO.inspect(label: "part2")

  # Day21.test_square(p, 100) |> IO.inspect()

  #                  Day21.run(program, [2]) |> IO.inspect(label: "part2")
  #            IO.inspect(Enum.map(layers, fn l -> Day21.count(l, "0") end))
  #                Day21.part1(layers) |> IO.inspect(label: "step1")
  #                Day21.display(layers, 25, 6)

  _ ->
    IO.puts("expected --test or input_file")
    #    System.halt(1)
end
