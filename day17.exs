#! /usr/bin/env elixir
defmodule Day17 do

  defmodule RobotGuidance do
    use Agent

    def start_link(initial_value) do
      init = to_charlist(initial_value)
      IO.inspect(init, label: "init val")
      Agent.start_link(fn -> init end, name: __MODULE__)
    end

    def next do
      f = fn([h|tail] = _state)->{h, tail} end
      Agent.get_and_update(__MODULE__, f) |> IO.inspect(label: "inp")
    end

  end

  defmodule Stdout do
    use Agent

    @scaffold 35

    defstruct map: %{}, x: 0, y: 0, img: []
    def start_link(initial_value \\ %Stdout{}) do
      Agent.start_link(fn -> initial_value end, name: __MODULE__)
    end

    def output(val) do
      updater = fn(%Stdout{}=s)->
        case val do
          10 -> %{s | x: 0, y: s.y+1, img: [val | s.img]}
          _ -> %{s | x: s.x+1, map: Map.put(s.map, {s.x,s.y}, val), img: [val | s.img]}
        end
      end
      Agent.update(__MODULE__, updater)
    end

    def crossings do
      IO.puts "in crossings"
      m = map()
      IO.inspect m
      reducer = fn({loc, val}, acc)->
        case val do
          @scaffold -> if crossing?(m, loc), do: [loc | acc], else: acc
          _ -> acc
        end
      end
      Enum.reduce(m, [], reducer)
    end

    def crossing?(map, {x,y}) do
      [{x+1,y}, {x-1,y}, {x,y-1}, {x,y+1}] |> Enum.map(&(map[&1])) |> Enum.all?(&(&1==@scaffold))
      end

    def puts do
      Agent.get(__MODULE__, &(&1.img |>Enum.reverse|> to_string|> IO.puts))
    end


    def counts() do
      Agent.get(__MODULE__, &(&1[:counts]))
    end
    def map() do
      Agent.get(__MODULE__, &(&1.map))
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


  @possible_dirs [{1,0}, {-1,0}, {0,1}, {0,-1}]

  def init(raw) do
    raw
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
  end

  def part1(input) do
    Stdout.start_link()

    initial_state = %{memory: input, pc: 0, map: %{}, stdout: &Stdout.output/1, guide: nil, loc: {0,0}, dir: {1,0}, rel_base: 0, state: :ready}
    #    oxygen = fn(next_states) -> Enum.find(next_states, fn(m)->Map.get(m,:state)==:done end) end
    final_m = Stream.iterate(initial_state, &(compute(&1)))
              |> Enum.reduce_while(nil, fn(m,_acc)-> case m[:state] do
                :ready -> {:cont, m }
                :halted -> {:halt, m}
                _ -> {:cont, m}
              end
              end)

    draw_screen()

    Stdout.crossings |> Enum.map(fn({x,y})-> x*y end) |> Enum.sum
  end

  @instructions     """
                    A,B,A,C,B,C,B,A,C,B
                    L,10,L,6,R,10
                    R,6,R,8,R,8,L,6,R,8
                    L,10,R,8,R,8,L,10
                    n
                    """
  def part2(input) do
    RobotGuidance.start_link(@instructions)
    IO.inspect @instructions

    # modify program
    input = List.replace_at(input, 0, 2)

    initial_state = %{memory: input, pc: 0, map: %{}, guide: &RobotGuidance.next/0, stdout: &IO.puts/1, loc: {0,0}, dir: {1,0}, rel_base: 0, state: :ready}
    final_m = Stream.iterate(initial_state, &(compute(&1)))
              |> Enum.reduce_while(nil, fn(m,_acc)-> case m[:state] do
                :ready -> {:cont, m }
                :halted -> {:halt, m}
                _ -> {:cont, m}
              end
              end)
  end

  @robots MapSet.new('v<>^')
  # def instructions(map) do
  #   {start,robot} = Enum.find(map, fn({loc,val})->MapSet.member?(val) end) 
  #   dir = direction(robot)

  #   dirs = turn_and_advance(map, %{loc: loc, dir: dir})

  #   forward = how_far_forward?(map, loc, dir)
  #   case forward>0 do
  #     true->[ List.to_string([0x30+forward]) | instrucs]
  #     _ -> instrucs
  #   end
  #   find_newdirection
  # end
  def possible_directions, do: [{0,1}, {0,-1}, {1,0}, {-1,0}]
  def direction(?v), do: {0,1}
  def direction(?^), do: {0,-1}
  def direction(?<), do: {-1,0}
  def direction(?>), do: {1,0}


  def draw_screen() do
    IO.puts("------------")
    Stdout.puts
    IO.puts("------------")
  end



  # machine = %{memory: input, pc: pc, map: map, outputs: outputs, rel_base: rel_base, state: state}
  def compute(%{state: :halted} = machine), do: machine
  def compute(%{state: _} = machine) do
    %{memory: input, pc: pc, stdout: stdout, guide: guide, loc: loc, dir: dir, rel_base: rel_base, state: state} = machine 
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
          inp_value=guide.()
          output = write(input, m1.( machine, pc+1), inp_value)
          %{machine | memory: output, pc: pc+2 }
      {:output,1, [m1], _f} -> 
          out_value =  m1.(machine, pc+1)
          stdout.(out_value)
          %{machine | pc: pc+2 }

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
    defmodule Day17Test do
      use ExUnit.Case

      # test "initial fuel" do
      #     assert Day17.run(Day17.init("1002,4,3,4,33"), 0,0) == 2
      #   end
      #      test "part2 " do
      #        assert Day17.run(Day17.init("3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99"), 8,0) == 2
      #        #assert Day17.run(Day17.init("3,12,6,12,15,1,13,14,13,4,13,99,-1,0,1,9"), 0,0) == 2
      #        #assert Day17.run(Day17.init("3,3,1105,-1,9,1101,0,0,12,4,12,99,1"), 0,0) == 2
      #        #assert Day17.run(Day17.init("5,9,10,104,0,99,104,1,99,1,6"), 0,0) == 2
      #      end

      test "simple" do
        source = "109,1,204,-1,1001,100,1,100,1008,100,16,101,1006,101,0,99"
        program = Day17.init(source)
        #machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day17.run(program, [])
        assert outputs == program
      end

      test "produce 16digit#" do
        source = "1102,34915192,34915192,7,4,7,99,0"
        program = Day17.init(source)
        #machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day17.run(program, [])
        assert 1_000_000_000_000_000 <= hd(outputs) && hd(outputs) < 10_000_000_000_000_000
      end

      test "my test of 203 " do
        source = "1102,34915192,34915192,7,4,7,99,0"
        program = Day17.init(source)
        #machine = %{memory: program, pc: 0, inputs: [], outputs: [], rel_base: 0, state: :ready}
        outputs = Day17.run(program, [])
        assert 1_000_000_000_000_000 <= hd(outputs) && hd(outputs) < 10_000_000_000_000_000
      end
    end


  [input_file] -> program = Day17.init(File.read!(input_file))
  #                p1 = Day17.part1(program) |> IO.inspect(label: "part1")
                  Day17.part2(program) |> IO.inspect(label: "part2")
                  #                  Day17.run(program, [2]) |> IO.inspect(label: "part2")
  #            IO.inspect(Enum.map(layers, fn l -> Day17.count(l, "0") end))
  #                Day17.part1(layers) |> IO.inspect(label: "step1")
  #                Day17.display(layers, 25, 6)

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
