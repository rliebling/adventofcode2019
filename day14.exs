#! /usr/bin/env elixir
defmodule Day14 do

  @ore "ORE"
  @fuel "FUEL"

  @trillion 1_000_000_000_000

  def init(raw) do
    list = raw
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_eqn/1)

    ingreds = list |> Enum.reduce(%{}, fn( {{chem, quant}, ingreds}=eqn, map) -> Map.put(map, chem, eqn) end)
    produces = list |> Enum.reduce(%{}, fn( {{chem, quant}, ingreds}=eqn, map) -> update_produces(ingreds, chem, map) end)
    {ingreds, produces}
  end

  def update_produces(ingreds, chem, map) do
    ingreds
    |> Enum.map(fn({chem,_})->chem end)
    |> Enum.reduce(map, fn(ingred, acc)->Map.update(acc, ingred, [chem], fn v->[chem | v] end) end)
  end

  def parse_eqn(line) do
    [ingreds, result] = line |> String.split("=>", trim: true)
    {parse_term(result), parse_ingreds(ingreds)}
  end

  def parse_term(str) do
    [quant, chem] = String.split(str, " ", trim: true)
    {chem, String.to_integer(quant)}
  end
  def parse_ingreds(ingreds) do
    ingreds
    |> String.split(",")
    |> Enum.map(&parse_term/1)
  end

  ####
  def part1(eqns, produces, fuel \\ 1) do
    priorities = calc_distances(@ore, produces, %{@ore=>0}, 0)
    #IO.inspect(priorities)
    get_or_produce(%{@fuel=> fuel}, eqns, priorities)
  end
  def part2(eqns, produces) do
    ore_per_fuel = part1(eqns, produces)
    lower_bound_fuel = div(@trillion,ore_per_fuel) # we know this will use < @trillion ore
    upper_bound_fuel = lower_bound_fuel*2
    f = fn fuel -> IO.puts("Calc for #{fuel}"); part1(eqns, produces, fuel) - @trillion end
    newton_raphson(lower_bound_fuel, upper_bound_fuel, f)

  end

  def newton_raphson(lower, upper, f) when upper-lower == 1 do
    lower
  end
  def newton_raphson(lower, upper, f) do
    case (val1= f.(lower)) < 0 do
      false -> IO.puts("Violates lower bound #{val1}")
      _ -> nil
    end
    case (val2=f.(upper)) > 0 do
      false -> IO.puts("Violates upper bound #{val2}")
      _ -> nil
    end
    #lower + (upper-lower)*abs(val1)/(val2+abs(val1))
    mid = div(val2*lower + abs(val1)*upper, val2+abs(val1)) |> max(lower+1) |> min(upper-1)
    
    IO.puts("NR: #{lower}, #{upper} #{mid} #{val1} #{val2}")
    new_val = f.(mid)
    cond do
      new_val > 0 -> newton_raphson(lower, mid, f)
      new_val == 0 -> new_val
      new_val < 0 -> newton_raphson(mid, upper, f)
    end
  end




  def calc_distances(chem, produces, distances, distance) do
    next =Map.get(produces, chem, [])
    new_distances = Enum.reduce(next, distances, fn(c, acc) -> 
                                            Map.update(acc,c, distance+1, &max(&1, distance+1)) end)

    next
    |> Enum.reduce(new_distances, &calc_distances(&1, produces, &2, distance+1))
  end

  def get_or_produce( needs, eqns, priorities) do
    #    {ores, non_ores} = Enum.split_with(needs, fn({chem, qty})-> chem==@ore end)
    #    ore_qty = case ores do
    #      [] -> 0
    #      [{_ore, qty}] -> qty
    #    end

    term = needs |> Enum.max_by(fn({chem,_})->Map.get(priorities, chem) end)

    #IO.puts("term=#{inspect term} needs=#{inspect needs}")
    reduce(term, needs, eqns, priorities)
  end

  def reduce({@ore,qty}, needs, eqns, priorities), do: qty
  def reduce({chem, _}=term, needs, eqns, priorities) do
    new_needs = produce(term, eqns)
    old_needs = Map.delete(needs, chem)

    #IO.puts("processed #{chem} newneeds #{inspect new_needs} old #{inspect old_needs}")

    reduced_needs = combine_terms(old_needs, new_needs)
    case Enum.count(reduced_needs) do
      1 -> reduced_needs[@ore]
      _ -> get_or_produce(reduced_needs, eqns, priorities)
    end
  end

  def produce({chem, need}, eqns) do
    {{_chem, quant}, ingreds} = eqns[chem]
    multiple = ceil(need/quant)
    #IO.puts("need #{need} chem #{chem} apply #{multiple} #{inspect ingreds}")

    Enum.map(ingreds, &mult_term(&1, multiple))
    |> Map.new
  end
  def combine_terms(a, b) do
    Map.merge(a, b, fn(key, qty1, qty2)-> qty1+qty2 end)
  end
  def mult_term({chem, qty}, multiple), do: {chem, qty*multiple}

end


case System.argv do
  ["--test"] -> ExUnit.start()
    defmodule Day14Test do
      use ExUnit.Case

      # test "initial fuel" do
      #     assert Day14.run(Day14.init("1002,4,3,4,33"), 0,0) == 2
      #   end
      #      test "part2 " do
      #        assert Day14.run(Day14.init("3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99"), 8,0) == 2
      #        #assert Day14.run(Day14.init("3,12,6,12,15,1,13,14,13,4,13,99,-1,0,1,9"), 0,0) == 2
      #        #assert Day14.run(Day14.init("3,3,1105,-1,9,1101,0,0,12,4,12,99,1"), 0,0) == 2
      #        #assert Day14.run(Day14.init("5,9,10,104,0,99,104,1,99,1,6"), 0,0) == 2
      #      end

      test "simple" do
        {eqns, produces} = Day14.init("""
          10 ORE => 10 A
          1 ORE => 1 B
          7 A, 1 B => 1 C
          7 A, 1 C => 1 D
          7 A, 1 D => 1 E
          7 A, 1 E => 1 FUEL
          """)
        assert 31 == Day14.part1(eqns, produces)
      end

    end


  [input_file] -> {e, p} = Day14.init(File.read!(input_file))
                           Day14.part1(e,p) |> IO.inspect(label: "part1")
                           Day14.part2(e,p) |> IO.inspect(label: "part2")
  #Day14.part1(program) |> IO.inspect(label: "part1")
  #                 Day14.part2(program) |> IO.inspect(label: "part2")
                  #                  Day14.run(program, [2]) |> IO.inspect(label: "part2")
  #            IO.inspect(Enum.map(layers, fn l -> Day14.count(l, "0") end))
  #                Day14.part1(layers) |> IO.inspect(label: "step1")
  #                Day14.display(layers, 25, 6)

  _ -> IO.puts("expected --test or input_file")
  #    System.halt(1)
end
