#! /usr/bin/env elixir
defmodule Day15 do
  @hit_wall 0
  @moved 1
  @oxygen 2

  @empty 10
  @wall 11
  @droid 12
  @origin 13
  @unknown nil
  def paint(@empty), do: "."
  def paint(@wall), do: "#"
  def paint(@droid), do: "D"
  def paint(@unknown), do: "?"
  def paint(@oxygen), do: "X"
  def paint(@origin), do: "O"

  defmodule ShipMap do
    use Agent

    def start_link(initial_value \\ %{map: %{}, counts: %{}}) do
      Agent.start_link(fn -> initial_value end, name: __MODULE__)
    end

    def counts() do
      Agent.get(__MODULE__, &(&1[:counts]))
    end
    def map() do
      Agent.get(__MODULE__, &(&1[:map]))
    end
    def has_visited?(key) do
      Agent.get(__MODULE__, &Map.has_key?(&1[:map], key))
    end
    def is_loc?(key, obj) do
      Map.get(ShipMap.map(), key)==obj
    end

    def put_map(key, value) do
      #IO.puts("ShipMap put #{inspect key} #{inspect value}")
      #Agent.update(__MODULE__, &put_in(&1[:map][key], fn(_)->value end))
      Agent.update(__MODULE__, fn(%{map: map}=s)-> %{s| map: Map.put(map, key, value)} end)
    end

    def put_count(key, value) do
      #Agent.update(__MODULE__, &put_in(&1[:counts][key], fn(_)->value end))
      Agent.update(__MODULE__, fn(%{counts: counts}=s)-> %{s| counts: Map.put(counts, key, value)} end)
    end

    def reset_visited(val) do
      resetter = fn(%{map: map}=s)-> %{s| map: (Enum.reject(map, fn({k,v})->v==val end) |> Map.new)} end
      Agent.update(__MODULE__, resetter)
    end
    def reset() do
      Agent.update(__MODULE__, &Map.put(&1, :counts, %{}))
      Agent.update(__MODULE__, &Map.put(&1, :map, %{}))
    end

  end

  defmodule CountMap do
    use Agent

    def start_link() do
      Agent.start_link(fn -> %{} end, name: __MODULE__)
    end

    def has_counted?(key) do
      Agent.get(__MODULE__, &Map.has_key?(&1, key))
    end

    def put(key, value) do
      Agent.update(__MODULE__, &Map.put(&1, key, value))
    end

    def get() do
      Agent.get(__MODULE__, &(&1))
    end
  end

  @possible_dirs [{1,0}, {-1,0}, {0,1}, {0,-1}]

  def init(raw) do
    raw
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
  end

  def part1(input) do
    ShipMap.start_link()

    initial_state = %{memory: input, pc: 0, map: %{}, guide: nil, loc: {0,0}, dir: {1,0}, rel_base: 0, state: :ready}
    oxygen = fn(next_states) -> Enum.find(next_states, fn(m)->Map.get(m,:state)==:done end) end
    stepper = fn({next_states, _ct}, step_count) -> case o=oxygen.(next_states) do
                nil ->{:cont, step_count+1}
                _ -> {:halt, {o, step_count}}
              end
    end
    {oxygen, count} =
      Stream.iterate({[initial_state], 1}, &move_once/1)
      |> Enum.reduce_while(0, stepper)
      |> IO.inspect

    draw_screen(ShipMap.map, oxygen[:loc])
    |> IO.inspect(label: "part1")

    {oxygen, count}
  end

  def part2(input) do
    ShipMap.reset_visited(@empty)
    draw_screen(ShipMap.map, {14, -20})
    initial_state = %{memory: input, pc: 0, map: %{}, guide: nil, loc: {0,0}, dir: {1,0}, rel_base: 0, state: :ready}

    stepper = fn( {next_states,_ct}, step_count) -> IO.inspect(Enum.map(next_states, &(&1[:loc])), label: "stepper")
              case length(next_states) do
                0 ->{:halt, step_count}
                _ -> {:cont, step_count+1}
              end
    end
    minutes =
      Stream.iterate({[initial_state], 1}, &move_once/1)
      |> Enum.reduce_while(0, stepper)
      |> IO.inspect(label: "part2")

    Enum.max_by(ShipMap.counts, fn({key, value})->value end)
    |> IO.inspect(label: "max count")

    draw_screen(ShipMap.map, {14, -20})
    IO.puts "Calculating"
    CountMap.start_link
    ShipMap.put_map({14,-21}, @wall) # unexplored, unfortunately
    find_count(ShipMap.map, [{14, -20}], 0)
    #IO.inspect(ShipMap.counts)

  end
  def find_count(_ship_map, [], count), do: count-1
  def find_count(ship_map, locs, count) do
    IO.puts "find_count #locs = #{inspect(locs)}"
    new_locs = Enum.flat_map(locs, &uncounted_adj_locs(ship_map, &1)) |> Enum.uniq
    Enum.map(new_locs, &CountMap.put(&1, count+1))
    find_count(ship_map, new_locs, count+1)
  end
  def uncounted_adj_locs(map, loc) do
    @possible_dirs
    |> Enum.map(&move1(loc, &1))
    #|> IO.inspect(label: "possibles")
    |> Enum.reject(&ShipMap.is_loc?(&1, @wall) )
    #|> IO.inspect(label: "no walls")
    |> Enum.reject(&CountMap.has_counted?(&1) )
    #|> IO.inspect(label: "end uncounted")
  end

  def move_once({states, count}) do
    IO.puts("move_once: locs=#{inspect Enum.map(states, &(&1[:loc]))}")
    next_states = Enum.flat_map(states, &(all_moves(&1, count)))
                  |>Enum.uniq_by(&(&1[:loc]))
    {next_states, count+1}
  end
  def all_moves(%{loc: loc}=m, count) do
    # draw_screen(ShipMap.map, loc)
    next_guides = Enum.reject(@possible_dirs, fn(d)->ShipMap.has_visited?(move1(loc,d)) end)
                  #|> IO.inspect(label: "all_moves")
                  |> Enum.map(fn(d)-> fn(_m, _l)->d end end)
    #IO.inspect(Enum.map(next_guides, &( &1.(0,0) )), label: "guides")
    Enum.map(next_guides, fn(g)->run_til_output(%{m | guide: g}, count) end)
  end

  def run_til_output(m, count) do
    Stream.iterate(m, &(compute(&1, count)))
    |> Enum.reduce_while(nil, fn(m,_acc)-> case m[:state] do
        :output -> {:halt, %{m | state: :ready}}
        :oxygen -> {:halt, %{m | state: :done}}
        _ -> {:cont, m}
      end
    end)
  end


  def draw_screen(map, loc) do
    IO.puts("------------")
    #map = Map.put(map, loc, @droid)
    map = Map.put(map, {0,0}, @origin)

    {{min_x,_},_} = Enum.min_by(map, fn({{x,_y},_color})->x end)
    {{max_x,_},_} = Enum.max_by(map, fn({{x,_y},_color})->x end)
    {{_, min_y},_} = Enum.min_by(map, fn({{_x,y},_color})->y end)
    {{_, max_y},_} = Enum.max_by(map, fn({{_x,y},_color})->y end)
    #IO.inspect {{min_x, max_y}, {max_x, min_y}, label: "screen range"}

    for y<- min_y..max_y do
      x_range = min_x..max_x
      IO.puts( Enum.map(x_range, &paint(Map.get(map, {&1,y}, @unknown))) |> Enum.join)
    end
    IO.puts("------------")
  end



  # machine = %{memory: input, pc: pc, map: map, outputs: outputs, rel_base: rel_base, state: state}
  def compute(%{state: :halted} = machine, count), do: machine
  def compute(%{state: _} = machine, count) do
    %{memory: input, pc: pc, guide: guide, loc: loc, dir: dir, rel_base: rel_base, state: state} = machine 
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
          #IO.puts("Moving from #{inspect loc}")
          case new_dir = guide.(ShipMap.map, loc) do
            :abort -> %{machine | pc: pc+2, state: :halted, retry: true }
            _ -> inp_value = determine_move(new_dir)
              #IO.puts("INPUT: #{inspect new_dir} #{inp_value}")
                  output = write(input, m1.( machine, pc+1), inp_value)
                  %{machine | memory: output, dir: new_dir, pc: pc+2 }
          end
      {:output,1, [m1], _f} -> 
          out_value =  m1.(machine, pc+1)
          #IO.puts("OUTPUT: #{out_value} loc #{inspect loc} dir=#{inspect dir}")
          case out_value do
            @hit_wall -> ShipMap.put_map(move1(loc,dir), @wall)
                         %{machine | pc: pc+2, state: :output}
            @moved -> new_loc = move1(loc,dir)
                      ShipMap.put_map(new_loc, @empty)
                      ShipMap.put_count(new_loc, count)
                      %{machine | pc: pc+2, loc: new_loc, state: :output }
            @oxygen -> new_loc = move1(loc,dir)
                       ShipMap.put_map(new_loc, @oxygen)
                       ShipMap.put_count(new_loc, count)
                       %{machine | loc: new_loc, state: :oxygen}
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

  def goal_guide(map, loc, goal) do
    visited = fn(d) -> Map.has_key?(map, move1(loc, d)) end
    unvisited_dirs = @possible_dirs |> Enum.reject(visited)

    case unvisited_dirs do
      [] -> :abort
      choices -> Enum.min_by(choices, fn(d)-> distance(goal, move1(loc, d)) end)
    end
  end
  def distance({x1,y1}, {x2,y2}), do: abs(x2-x1) + abs(y2-y1)

  def choose_dir(map, loc) do
    visited = fn(d) -> Map.has_key?(map, move1(loc, d)) end
    unvisited_dirs = @possible_dirs |> Enum.reject(visited)

    case unvisited_dirs do
      [] -> walled = fn(d) -> Map.get(map, move1(loc, d)) == @wall end
            @possible_dirs |> Enum.reject(walled) |> Enum.random
      choices -> Enum.random(choices)
    end
  end

  def determine_move({1,0}), do: 4 
  def determine_move({-1,0}), do: 3 
  def determine_move({0,1}), do: 2 
  def determine_move({0,-1}), do: 1 

  def move1({x,y}=_loc, {dx,dy}=_dir) do
    {x+dx, y+dy}
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
    defmodule Day15Test do
      use ExUnit.Case

      # test "initial fuel" do
      #     assert Day15.run(Day15.init("1002,4,3,4,33"), 0,0) == 2
      #   end
      #      test "part2 " do
      #        assert Day15.run(Day15.init("3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99"), 8,0) == 2
      #        #assert Day15.run(Day15.init("3,12,6,12,15,1,13,14,13,4,13,99,-1,0,1,9"), 0,0) == 2
      #        #assert Day15.run(Day15.init("3,3,1105,-1,9,1101,0,0,12,4,12,99,1"), 0,0) == 2
      #        #assert Day15.run(Day15.init("5,9,10,104,0,99,104,1,99,1,6"), 0,0) == 2
      #      end

      test "simple" do
        source = "109,1,204,-1,1001,100,1,100,1008,100,16,101,1006,101,0,99"
        program = Day15.init(source)
        #machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day15.run(program, [])
        assert outputs == program
      end

      test "produce 16digit#" do
        source = "1102,34915192,34915192,7,4,7,99,0"
        program = Day15.init(source)
        #machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day15.run(program, [])
        assert 1_000_000_000_000_000 <= hd(outputs) && hd(outputs) < 10_000_000_000_000_000
      end

      test "my test of 203 " do
        source = "1102,34915192,34915192,7,4,7,99,0"
        program = Day15.init(source)
        #machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day15.run(program, [])
        assert 1_000_000_000_000_000 <= hd(outputs) && hd(outputs) < 10_000_000_000_000_000
      end
    end


  [input_file] -> program = Day15.init(File.read!(input_file))
                  {oxy, steps} = Day15.part1(program) |> IO.inspect(label: "part1")
                  Day15.part2(program) |> IO.inspect(label: "part2")
                  #                  Day15.run(program, [2]) |> IO.inspect(label: "part2")
  #            IO.inspect(Enum.map(layers, fn l -> Day15.count(l, "0") end))
  #                Day15.part1(layers) |> IO.inspect(label: "step1")
  #                Day15.display(layers, 25, 6)

  _ -> IO.puts("expected --test or input_file")
  #    System.halt(1)
end


###########

#          ?#####?#############?#?#########??####?
#          #.....#.............#.#.........#X....#
#          #.#.###.#####.#####.#.#.#####.#.#####.#
#          #.#.......#...#.#...#.....#...#...#...#
#          #.#########.###.#.#########.#####.#.##?
#          #.#.#.......#.....#.......#.#.....#...#
#          #.#.#.#########.#####.###.#.#.#####.#.#
#          #.#.#.........#.#.....#.....#.#.#...#.#
#          #.#.#########.#.#.#.#########.#.#.###.#
#          #.....#...#...#...#.#...#.....#...#...#
#          ?####.#.#.#.#####.###.#.#####.#####.#.#
#          ????#.#.#.#.....#.#...#.....#.......#.#
#          ????#.###.#####.#.#.##?####.##########?
#          ????#.......#...#.#.#?????#.#.........#
#          ?????######.#.###.#.##????#.#.#######.#
#          ??????#.....#...#.#...#???#.....#.....#
#          ??????#.####?##.#####.#????######.###.#
#          ??????#...#???#.......#???????#...#...#
#          ???????##.##???#######????????#.###.##?
#          ????????#...#?????????????????#.#.....#
#          ???????####.#??#####??????????#.#####.#
#          ??????#...#.#.#....O#?????????#...#...#
#          ??????#.#.#.#.#.########???????##.###.#
#          ??????#.#...#.#...#.....#???????#...#.#
#          ?????##.#####.###.#.###.#??########.#.#
#          ????#...#.......#.#.#?#.#?#.......#.#.#
#          ????#.##?####.###.#.#?#.###.#####.#.#.#
#          ????#...#.....#...#.#?#.....#.#...#.#.#
#          ?????##.#.###.#.###.#??######.#.###.##?
#          ??????#...#...#.#...#???????#...#.....#
#          ???????####.###.###.#???????#.#####.#.#
#          ???????????.??#.....#???????#.#...#.#.#
#          ???????????????#####????????#.#.#.###.#
#          ????????????????????????????#...#...#.#
#          ?????????????????????????????###?##.#.#
#          ??????????????????????????????????#...#
#          ???????????????????????????????????###?
