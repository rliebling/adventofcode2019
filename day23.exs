#! /usr/bin/env elixir

defmodule Day23 do
  require Logger

  defmodule Mapper do
    use Agent

    defstruct inputs: nil, outputs: nil, nat: nil, recent_activity: true

    def start_link(num_addrs) do
      outputs = for(i <- 0..(num_addrs - 1), do: {i, []}) |> Map.new()
      inputs = for(i <- 0..(num_addrs - 1), do: {i, [i]}) |> Map.new()
      Agent.start_link(fn -> %Mapper{inputs: inputs, outputs: outputs} end, name: __MODULE__)

      Task.async(&poll_for_activity/0)
    end

    def poll_for_activity do
      Logger.info("poll_for_activity")

      receive do
      after
        1_000 ->
          Mapper.check_idle()
          poll_for_activity
      end
    end

    # reset recent activity.  If was false, then deliver nat packet to addr 0
    def check_idle do
      f = fn
        %Mapper{recent_activity: true} = s ->
          %Mapper{s | recent_activity: false}

        %Mapper{recent_activity: false} = s ->
          Logger.info("IDLE: setting input for 0 to #{inspect(s.nat)}")
          %Mapper{s | inputs: Map.put(s.inputs, 0, s.nat), recent_activity: false}
      end

      Logger.info("check_idle")
      n = Agent.update(__MODULE__, f)
    end

    def next(addr) do
      f = fn %Mapper{inputs: inputs} = s ->
        case inputs[addr] do
          [h | tail] ->
            {h, %Mapper{s | recent_activity: true, inputs: Map.put(inputs, addr, tail)}}

          [] ->
            {-1, s}
        end
      end

      n = Agent.get_and_update(__MODULE__, f)
      if n != -1, do: Logger.info("input addr=#{addr} val=#{n}")
      n
    end

    def output(val, addr) do
      Logger.info("output addr=#{addr} val=#{val}")

      updater = fn %Mapper{outputs: outputs} = s ->
        case outputs[addr] do
          [x, a] ->
            # remember buffered in reverse order, and val will be the y
            new_out = Map.put(outputs, addr, [])

            case a == 255 do
              true ->
                Logger.info("Set NAT to #{x},#{val}")

                if s.nat != nil && Enum.at(s.nat, 1) == val do
                  IO.puts("Repeated y val to NAT: #{val}")
                  System.halt(1)
                end

                %Mapper{s | outputs: new_out, nat: [x, val], recent_activity: true}

              false ->
                new_in = Map.update(s.inputs, a, nil, &(&1 ++ [x, val]))
                Logger.info("deliver #{x},#{val} to addr=#{a}")
                %Mapper{s | outputs: new_out, inputs: new_in, recent_activity: true}
            end

          _ ->
            %Mapper{
              s
              | outputs: Map.put(outputs, addr, [val | outputs[addr]]),
                recent_activity: true
            }
        end
      end

      Agent.update(__MODULE__, updater)
    end
  end

  def init(raw) do
    raw
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
  end

  def part1(input) do
    num_addrs = 50
    Mapper.start_link(num_addrs)

    tasks =
      for a <- 0..(num_addrs - 1) do
        inp_fn = fn -> Mapper.next(a) end

        Task.async(fn ->
          initial_state = %{
            memory: input,
            pc: 0,
            map: %{},
            stdout: &Mapper.output(&1, a),
            guide: inp_fn,
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
        end)
      end

    tasks_with_results = Task.yield_many(tasks, 120_000) |> IO.inspect(label: "tasks")
    # Mapper.puts()
    # IO.inspect(Mapper.count_affected(), label: "part1 count")
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

    defmodule Day23Test do
      use ExUnit.Case
    end

  [input_file] ->
    program = Day23.init(File.read!(input_file))
    p1 = Day23.part1(program) |> IO.inspect(label: "part1")

  #    p = Day23.part2(program) |> IO.inspect(label: "part2")

  _ ->
    IO.puts("expected --test or input_file")
    #    System.halt(1)
end
