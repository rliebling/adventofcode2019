#! /usr/bin/env elixir
#
defmodule Day25 do
  require Bitwise

  defmodule Mapper do
    use Agent

    alias Day25.InvMgr

    defstruct input: [], output: [], auto: false

    @initial_instrs """
    north
    west
    take mug
    west
    take easter egg
    east
    east
    south
    south
    take asterisk
    south
    west
    north
    take jam
    south
    east
    north
    east
    take klein bottle
    south
    west
    take tambourine
    west
    take cake
    east
    south
    east
    take polygon
    north
    """

    def start_link() do
      Agent.start_link(fn -> %Mapper{input: to_input(@initial_instrs)} end, name: __MODULE__)
      # Agent.start_link(fn -> %Mapper{input: []} end, name: __MODULE__)
    end

    def next do
      f = fn
        %Mapper{input: [h | tail]} = s -> {h, %Mapper{s | input: tail}}
        %Mapper{auto: true} = s -> {:auto, s}
        %Mapper{input: []} = s -> {:empty, s}
      end

      case Agent.get_and_update(__MODULE__, f) do
        :empty ->
          inp = IO.read(:stdio, :line) |> String.trim()

          # String.match?(inp, ~r(Security Checkpoint)) do
          case inp == "auto" do
            true ->
              {auto, instrs} = InvMgr.instructions() |> IO.inspect(label: "got instructions")
              [h | instrs] = instrs |> to_input
              Agent.update(__MODULE__, &%Mapper{&1 | input: instrs, auto: auto})
              h

            false ->
              [h | tail] = inp |> to_input
              Agent.update(__MODULE__, &%Mapper{&1 | input: tail})
              h
          end

        :auto ->
          {auto, instrs} = InvMgr.instructions()
          [h | instrs] = instrs |> to_input
          Agent.update(__MODULE__, &%Mapper{&1 | input: instrs, auto: auto})
          h

        x ->
          x
      end
    end

    def to_input(s), do: to_charlist(s) ++ [?\n]

    def output(val) do
      updater = fn %Mapper{} = s ->
        %Mapper{s | output: [val | s.output]}
      end

      case val do
        ?\n ->
          {output, auto} =
            Agent.get_and_update(__MODULE__, &{{&1.output, &1.auto}, %Mapper{&1 | output: []}})

          out_str = output |> to_string |> String.reverse()
          IO.puts(out_str)

          if auto, do: InvMgr.response(out_str)

        _ ->
          Agent.update(__MODULE__, updater)
      end
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

  defmodule InvMgr do
    defstruct inv: [], state: :start, resp_state: :none, inv: [], attempt: nil, attempt_all: nil

    def start_link() do
      Agent.start_link(fn -> %InvMgr{} end, name: __MODULE__)
    end

    def instructions do
      IO.inspect(Agent.get(__MODULE__, &{&1.state, &1.resp_state}), label: "in instructions")

      case Agent.get(__MODULE__, &{&1.state, &1.resp_state}) do
        {:start, _} ->
          Agent.update(__MODULE__, &%InvMgr{&1 | state: :working, resp_state: :rcv_inv})
          {true, "inv"}

        {_, :rcv_inv} ->
          {false, "no instructions while collecting inventory"}

        {_, :inv_done} ->
          {true, next_try()}

        {:east, _} ->
          Agent.update(__MODULE__, &%InvMgr{&1 | state: :done})
          {true, "east"}

        {:done, _} ->
          {false, "inv"}
      end
      |> IO.inspect(label: "instructions returned")
    end

    # Items in your inventory:
    # - easter egg
    # - tambourine
    # - asterisk
    # - klein bottle
    # - cake
    def response(str) do
      cond do
        String.match?(str, ~r(Items in your inventory:)) ->
          set_resp_state(:rcv_inv)

        String.match?(str, ~r(^-\s)) && resp_state() == :rcv_inv ->
          add_inv(String.slice(str, 2..-1))

        str == "Command?" && resp_state == :rcv_inv ->
          initialize_attempts()
          set_resp_state(:inv_done)

        true ->
          # IO.inspect(str, label: "response")
          nil
      end
    end

    # interpret attempt as binary # expressing which inv items to keep
    # starts with keeping all of them
    # cycle stops when it reaches 0
    def initialize_attempts do
      f = fn s ->
        count = length(s.inv)
        attempt = power(2, count) - 1
        %InvMgr{s | attempt: attempt, attempt_all: attempt}
      end

      Agent.update(__MODULE__, f)
    end

    def next_try do
      f = fn
        %InvMgr{attempt: 0, inv: inv} = s ->
          {{inv, 0, 0}, s}

        %InvMgr{attempt: attempt, inv: inv} = s ->
          prev_attempt = if attempt == s.attempt_all, do: s.attempt_all, else: attempt + 1
          diff = Bitwise.bxor(attempt, prev_attempt) |> Bitwise.band(s.attempt_all)

          {{inv, diff, attempt}, %InvMgr{s | attempt: attempt - 1}}
      end

      {inv, diff, want} = Agent.get_and_update(__MODULE__, f)

      diff_list = binary_to_list(diff, length(inv))
      want_list = binary_to_list(want, length(inv))

      takes_and_drops =
        Enum.zip(inv, diff_list)
        |> Enum.zip(want_list)
        |> Enum.flat_map(fn
          # {item, change, want}
          {{item, true}, true} -> ["take #{item}"]
          {{item, true}, false} -> ["drop #{item}"]
          {{item, false}, _} -> []
        end)
        |> Enum.join("\n")

      if diff != 0 or want != 0 do
        takes_and_drops <> "\neast"
      else
        Agent.update(__MODULE__, &%InvMgr{&1 | state: :done})
        "done"
      end
      |> IO.inspect(label: "next_try #{diff} #{want} #{inspect(diff_list)} #{inspect(want_list)}")
    end

    def resp_state, do: Agent.get(__MODULE__, & &1.resp_state)
    def set_resp_state(s), do: Agent.update(__MODULE__, &%InvMgr{&1 | resp_state: s})

    def add_inv(i) do
      IO.puts("add_inv: #{i}")
      Agent.update(__MODULE__, &%InvMgr{&1 | inv: [i | &1.inv]})
    end

    def power(b, e), do: :math.pow(b, e) |> trunc

    def binary_to_list(val, len) do
      Integer.to_string(val, 2)
      |> String.pad_leading(len, "0")
      |> String.split("", trim: true)
      |> Enum.map(&(&1 == "1"))
    end
  end

  def init(raw) do
    raw
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
  end

  def part1(input) do
    Mapper.start_link()
    InvMgr.start_link()

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

    defmodule Day25Test do
      use ExUnit.Case
    end

  [input_file] ->
    program = Day25.init(File.read!(input_file))
    p1 = Day25.part1(program) |> IO.inspect(label: "part1")

  # p = Day21.part2(program) |> IO.inspect(label: "part2")

  # Day21.test_square(p, 100) |> IO.inspect()

  #                  Day21.run(program, [2]) |> IO.inspect(label: "part2")
  #            IO.inspect(Enum.map(layers, fn l -> Day21.count(l, "0") end))
  #                Day21.part1(layers) |> IO.inspect(label: "step1")
  #                Day21.display(layers, 25, 6)

  _ ->
    IO.puts("expected --test or input_file")
    #    System.halt(1)
end
