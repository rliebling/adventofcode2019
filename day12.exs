#! /usr/bin/env elixir
defmodule Day12 do

  @initial_velocity {0,0,0}

  # return an array of points(tuples)
  # from <x=1, y=2, z=3>
  def init(str) do
    str
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_point/1)
    |> Enum.map(fn pt -> %{loc: pt, vel: @initial_velocity} end)
  end


  def parse_point(line) do
    line
    |> String.slice(1,String.length(line)-2) # lose the "<" and ">"
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn c -> {_, number} = String.split_at(c,2); String.to_integer(number) end)
    |> List.to_tuple
  end

  def part1(moons, steps) do
    Stream.iterate(moons, &update_moons/1)
    |> Stream.map(fn ms -> Enum.map(ms, &total_energy/1)|> IO.inspect; ms end)
    |> Enum.at(steps)
    |> IO.inspect
    |> Enum.map(&total_energy/1)
    |> Enum.sum
  end

  def part2(moons) do
    x_moons = Enum.map(moons,&project(0, &1))
    y_moons = Enum.map(moons,&project(1, &1))
    z_moons = Enum.map(moons,&project(2, &1))

    [x_moons, y_moons, z_moons]
    |> Enum.map(&do_part2/1)
    |> Enum.map(&elem(&1, 1))
    |> lcm
  end

  def lcm([]), do: 1
  def lcm([a]), do: a
  def lcm([a, b | rest]), do: lcm( [ lcm(a,b) | rest ] )
  def lcm(0, 0), do: 0
  def lcm(a, b), do: trunc((a*b)/gcd(a,b))
  def gcd(a, 0), do: a
  def gcd(0, b), do: b
  def gcd(a, b), do: gcd(b, rem(a,b))
	
  def project(idx, %{loc: loc}) do
    %{loc: {elem(loc, idx), 0,0}, vel: @initial_velocity}
  end 

  def do_part2(moons) do
    Stream.iterate(moons, &update_moons/1)
    #|> Stream.map(fn ms -> Enum.map(ms, &total_energy/1)|> IO.inspect; ms end)
    |> Enum.reduce_while({%{},0}, fn state, {accum,count} -> case Map.has_key?(accum, state) do
    #|> Enum.reduce_while({%{},0}, fn state, {accum,count} -> case (Enum.map(state, &total_energy/1) == [0,0,0,0] && count>0) do
                                        true -> {:halt, {Map.get(accum, state), Map.size(accum)}}
                                        false -> {:cont, {Map.put(accum, state, count+1), count+1}}
        end
    end)
  end
  
  def total_energy(%{loc: loc, vel: vel}) do
    energy(loc) * energy(vel)
  end
  def energy({x,y,z}) do
    abs(x) + abs(y) + abs(z)
  end

  def update_moons(moons) do
    moons
    |> apply_gravity
    |> update_location
  end

  def apply_gravity([]), do: []
  def apply_gravity([moon | others]) do
    {new_others, new_moon} = Enum.map_reduce(others, moon, &apply_gravity_to_pair(&1, &2))
    [new_moon | apply_gravity(new_others) ]
  end

  # get passed the accumulator of map_reduce in second arg
  # return {result, accum} = {a, b}
  def apply_gravity_to_pair(%{loc: a_loc, vel: a_vel}=a, %{loc: b_loc, vel: b_vel}=b) do
    a_delta = delta_vel(a_loc, b_loc)

    {adjust_vel(a, a_delta), adjust_vel_opposite(b, a_delta)}
  end
  def delta_vel({ax, ay, az}, {bx, by, bz}) do
    {dir(bx-ax), dir(by-ay), dir(bz-az)}
  end
  def dir(diff) do
    cond do
      diff < 0 -> -1
      diff == 0 -> 0
      diff > 0 -> 1
    end
  end
  def adjust_vel(%{vel: {v1,v2,v3}}=moon, {d1,d2,d3}=_delta) do
    %{moon | vel: {v1+d1, v2+d2, v3+d3}}
  end
  def adjust_vel_opposite(%{vel: {v1,v2,v3}}=moon, {d1,d2,d3}=_delta) do
    %{moon | vel: {v1-d1, v2-d2, v3-d3}}
  end

  def update_location(moons) when is_list(moons) do
    moons
    |> Enum.map(&update_location(&1))
  end
  def update_location(%{loc: {x,y,z}, vel: {vx, vy, vz}=v}) do
    %{loc: {x+vx, y+vy, z+vz}, vel: v}
  end

end



case System.argv do
  ["--test"] -> ExUnit.start()
    defmodule Day12Test do
      use ExUnit.Case

      # test "initial fuel" do
      #     assert Day12.run(Day12.init("1002,4,3,4,33"), 0,0) == 2
      #   end
      #      test "part2 " do
      #        assert Day12.run(Day12.init("3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99"), 8,0) == 2
      #        #assert Day12.run(Day12.init("3,12,6,12,15,1,13,14,13,4,13,99,-1,0,1,9"), 0,0) == 2
      #        #assert Day12.run(Day12.init("3,3,1105,-1,9,1101,0,0,12,4,12,99,1"), 0,0) == 2
      #        #assert Day12.run(Day12.init("5,9,10,104,0,99,104,1,99,1,6"), 0,0) == 2
      #      end

    #      test "simple" do
    #        moons = Day12.init("""
    #          <x=-8, y=-10, z=0>
    #          <x=5, y=5, z=10>
    #          <x=2, y=-7, z=3>
    #          <x=9, y=-8, z=-3>
    #          """)
    #        Day12.part1(moons, 100) |> IO.inspect
    #    #Day12.part2(moons) |> IO.inspect
    #      end
    #      test "part2" do
    #        moons = Day12.init("""
    #          <x=-1, y=0, z=2>
    #          <x=2, y=-10, z=-7>
    #          <x=4, y=-8, z=8>
    #          <x=3, y=5, z=-1>
    #          """)
    #        Day12.part1(moons, 18*28*44) |> IO.inspect
    #        Day12.part2(moons) |> IO.inspect
    #      end
      test "part2" do
        moons = Day12.init("""
          <x=-1, y=0, z=2>
          <x=2, y=-10, z=-7>
          <x=4, y=-8, z=8>
          <x=3, y=5, z=-1>
          """)
        #        Day12.part1(moons, 18) |> IO.inspect
        #Day12.part1(moons, 14) |> IO.inspect
        #Day12.part1(moons, 11) |> IO.inspect
        #Day12.part1(moons, 11) |> IO.inspect
        Day12.part2(moons) |> IO.inspect
      end

    end


  [input_file] -> moons = Day12.init(File.read!(input_file)) |> IO.inspect
                  Day12.part1(moons, 1000) |> IO.inspect
                  Day12.part2(moons) |> IO.inspect
  # Day12.part1(program) |> IO.inspect(label: "part1")
  #                Day12.part2(program) |> IO.inspect(label: "part2")
                  #                  Day12.run(program, [2]) |> IO.inspect(label: "part2")
  #            IO.inspect(Enum.map(layers, fn l -> Day12.count(l, "0") end))
  #                Day12.part1(layers) |> IO.inspect(label: "step1")
  #                Day12.display(layers, 25, 6)

  _ -> IO.puts("expected --test or input_file")
  #    System.halt(1)
end
