#! /usr/bin/env elixir
defmodule Day19 do
  @scan_sequence for(
                   x <- 0..49,
                   y <- 0..49,
                   do: [x, y]
                 )
                 |> Enum.flat_map(& &1)

  defmodule Runner do
    use Agent

    defstruct program: nil, input: [], output: []

    def start_link(program) do
      Agent.start_link(fn -> %Runner{program: program} end, name: __MODULE__)
    end

    def test(point) do
      Agent.update(__MODULE__, fn s -> %Runner{s | input: Tuple.to_list(point), output: []} end)

      s = Agent.get(__MODULE__, & &1)
      # IO.inspect(s, label: "Runner.test #{inspect(point)}")

      initial_state = %{
        memory: s.program,
        pc: 0,
        map: %{},
        stdout: &Runner.output/1,
        guide: &Runner.next/0,
        loc: {0, 0},
        dir: {1, 0},
        rel_base: 0,
        state: :ready
      }

      _final_m =
        Stream.iterate(initial_state, &Day19.compute(&1))
        |> Enum.reduce_while(nil, fn m, _acc ->
          case m[:state] do
            :ready -> {:cont, m}
            :halted -> {:halt, m}
            _ -> {:cont, m}
          end
        end)

      Agent.get(__MODULE__, & &1).output |> hd()
    end

    def next do
      f = fn
        %Runner{input: [h | tail]} = state -> {h, %Runner{state | input: tail}}
        s -> IO.inspect(s, label: "unmatched state in next/0")
      end

      Agent.get_and_update(__MODULE__, f)
    end

    def output(val) do
      updater = fn %Runner{} = s ->
        %Runner{s | output: [val | s.output]}
      end

      Agent.update(__MODULE__, updater)
    end
  end

  defmodule Part1Drone do
    use Agent

    def start_link(init) do
      Agent.start_link(fn -> init end, name: __MODULE__)
    end

    def next do
      f = fn [h | tail] = _state -> {h, tail} end
      Agent.get_and_update(__MODULE__, f)
    end
  end

  defmodule Mapper do
    use Agent

    defstruct list: []

    def start_link(initial_value \\ %Mapper{}) do
      Agent.start_link(fn -> initial_value end, name: __MODULE__)
    end

    def output(val) do
      updater = fn %Mapper{} = s ->
        %Mapper{s | list: [val | s.list]}
      end

      Agent.update(__MODULE__, updater)
    end

    def puts do
      Agent.get(__MODULE__, & &1.list)
      |> Enum.reverse()
      |> Enum.map(fn v -> if v == 1, do: "#", else: "." end)
      |> Enum.chunk_every(50)
      |> Enum.map(&Enum.join(&1, ""))
      |> Enum.join("\n")
      |> IO.puts()
    end

    def count_affected do
      Agent.get(__MODULE__, & &1.list)
      |> Enum.count(&(&1 == 1))
    end
  end

  @possible_dirs [{1, 0}, {-1, 0}, {0, 1}, {0, -1}]

  def init(raw) do
    raw
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
  end

  def part1(input) do
    Part1Drone.start_link(@scan_sequence)
    Mapper.start_link()

    initial_state = %{
      memory: input,
      pc: 0,
      map: %{},
      stdout: &Mapper.output/1,
      guide: &Part1Drone.next/0,
      loc: {0, 0},
      dir: {1, 0},
      rel_base: 0,
      state: :ready
    }

    count = div(length(@scan_sequence), 2)

    for i <- 1..count,
        do:
          final_m =
            Stream.iterate(initial_state, &compute(&1))
            |> Enum.reduce_while(nil, fn m, _acc ->
              case m[:state] do
                :ready -> {:cont, m}
                :halted -> {:halt, m}
                _ -> {:cont, m}
              end
            end)

    # draw_screen()

    Mapper.puts()
    IO.inspect(Mapper.count_affected(), label: "part1 count")
  end

  def part2(input) do
    IO.puts("part2 size(input) = #{length(input)}")
    Runner.start_link(input)

    # can fit 4x4 at 34,46
    # start at 25 * (34,46)
    # check if pulled
    # Binary search (doubling row if not fit)
    # examine a row
    #   start at (row, row) and binary search for the end
    #   find 100 before end of affected area
    #   check 100 down
    #   
    start_point = {30 * 49, 30 * 40}
    min_point = {20 * 49, 20 * 40}

    IO.inspect(Runner.test({49, 40}))
    IO.inspect(Runner.test(start_point))
    IO.inspect(Runner.test(min_point))
    min = find_max_x_affected(min_point) |> IO.inspect(label: "min x2")
    max = find_max_x_affected(start_point) |> IO.inspect(label: "max x")

    test_square(min, 100) |> IO.inspect(label: "test square #{inspect(min)}")
    test_square(max, 100) |> IO.inspect(label: "test square #{inspect(max)}")

    {x, max_too_small_y} =
      Stream.iterate(30 * 40, fn y -> y - 1 end)
      |> Stream.map(&find_max_x_affected({div(&1 * 49, 40), &1}))
      |> Enum.find(&(test_square(&1, 100) == false))

    {x, y} = find_max_x_affected({x, max_too_small_y + 1})

    for(
      xx <- (x - 100)..x,
      test_square({xx, y}, 100),
      do: xx
    )
    |> Enum.take(1)
    |> hd
    |> upper_left_corner(y, 100)
  end

  def upper_left_corner(x, y, size), do: {x - size + 1, y}

  def test_square({x, y}, size) do
    p1 = upper_left_corner(x, y, size)
    p2 = {x - size + 1, y + size - 1}

    Runner.test(p1) == 1 &&
      Runner.test(p2) == 1

    # |> IO.inspect(label: "test_square internal {#{x}, #{y}} corner=#{inspect(p1)}")
  end

  def find_max_x_affected({x, y} = p) do
    {affected, _, _} =
      Stream.iterate({p, 50, 1}, fn {{x, y}, dx, sign} = s ->
        # IO.inspect(s, label: "find_max_x_affected")
        {{x + sign * dx, y}, dx + 100, -1 * sign}
      end)
      |> Enum.find(fn {p, _, _} -> Runner.test(p) == 1 end)

    {unaffected, _} =
      Stream.iterate({p, 50}, fn {{x, y}, dx} = s ->
        # IO.inspect(s, label: "find_max_x_unaffected")
        {{x + dx, y}, dx + 100}
      end)
      |> Enum.find(fn {p, _} -> Runner.test(p) == 0 end)

    binary_search({affected, unaffected}, &Runner.test/1)
  end

  def binary_search({{x1, _y} = min, {x2, y}}, f) when x2 - x1 == 1, do: min

  def binary_search({min, max}, f) do
    p = midpoint(min, max)
    # IO.puts("binary_search #{inspect(min)} #{inspect(max)} #{inspect(p)}")

    case f.(p) do
      1 -> binary_search({p, max}, f)
      _ -> binary_search({min, p}, f)
    end
  end

  def midpoint({x1, _}, {x2, y}), do: {div(x1 + x2, 2), y}

  def fits?(point) do
    last_x_affected = Runner.test(point)
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

    defmodule Day19Test do
      use ExUnit.Case

      # test "initial fuel" do
      #     assert Day19.run(Day19.init("1002,4,3,4,33"), 0,0) == 2
      #   end
      #      test "part2 " do
      #        assert Day19.run(Day19.init("3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99"), 8,0) == 2
      #        #assert Day19.run(Day19.init("3,12,6,12,15,1,13,14,13,4,13,99,-1,0,1,9"), 0,0) == 2
      #        #assert Day19.run(Day19.init("3,3,1105,-1,9,1101,0,0,12,4,12,99,1"), 0,0) == 2
      #        #assert Day19.run(Day19.init("5,9,10,104,0,99,104,1,99,1,6"), 0,0) == 2
      #      end

      test "simple" do
        source = "109,1,204,-1,1001,100,1,100,1008,100,16,101,1006,101,0,99"
        program = Day19.init(source)
        # machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day19.run(program, [])
        assert outputs == program
      end

      test "produce 16digit#" do
        source = "1102,34915192,34915192,7,4,7,99,0"
        program = Day19.init(source)
        # machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day19.run(program, [])
        assert 1_000_000_000_000_000 <= hd(outputs) && hd(outputs) < 10_000_000_000_000_000
      end

      test "my test of 203 " do
        source = "1102,34915192,34915192,7,4,7,99,0"
        program = Day19.init(source)
        # machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day19.run(program, [])
        assert 1_000_000_000_000_000 <= hd(outputs) && hd(outputs) < 10_000_000_000_000_000
      end
    end

  [input_file] ->
    program = Day19.init(File.read!(input_file))
    # p1 = Day19.part1(program) |> IO.inspect(label: "part1")

    p = Day19.part2(program) |> IO.inspect(label: "part2")
    Day19.test_square(p, 100) |> IO.inspect()

  #                  Day19.run(program, [2]) |> IO.inspect(label: "part2")
  #            IO.inspect(Enum.map(layers, fn l -> Day19.count(l, "0") end))
  #                Day19.part1(layers) |> IO.inspect(label: "step1")
  #                Day19.display(layers, 25, 6)

  _ ->
    IO.puts("expected --test or input_file")
    #    System.halt(1)
end

#    #.................................................
#    ..................................................
#    ..................................................
#    ..................................................
#    ..................................................
#    ....#.............................................
#    .....#............................................
#    ......#...........................................
#    .......#..........................................
#    .......#..........................................
#    ........#.........................................
#    .........#........................................
#    ..........#.......................................
#    ..........##......................................
#    ...........##.....................................
#    ............##....................................
#    .............##...................................
#    .............###..................................
#    ..............##..................................
#    ...............##.................................
#    ................##................................
#    ................###...............................
#    .................###..............................
#    ..................###.............................
#    ...................###............................
#    ...................####...........................
#    ....................####..........................
#    .....................###..........................
#    ......................###.........................
#    ......................####........................
#    .......................####.......................
#    ........................####......................
#    .........................####.....................
#    .........................#####....................
#    ..........................#####...................
#    ...........................#####..................
#    ............................####..................
#    ............................#####.................
#    .............................#####................
#    ..............................#####...............
#    ...............................#####..............
#    ...............................######.............
#    ................................######............
#    .................................######...........
#    ..................................######..........
#    ..................................######..........
#    ...................................######.........
#    ....................................######........
#    .....................................######.......
#    .....................................#######......
