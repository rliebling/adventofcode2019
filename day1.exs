#! /usr/bin/env elixir
defmodule Day1 do


  def fuel(input) do
    input
    |> String.split("\n", trim: true)
    |> Enum.map(&String.to_integer/1)
    |> Enum.map(&fuel_for_mass/1)
    |> Enum.sum()
  end

  defp fuel_for_mass(mass) do
    case div(mass,3) -2 do
      x when x>=0 -> x
      _ -> 0
    end
  end

  def total_fuel(input) do
    input
    |> String.split("\n", trim: true)
    |> Enum.map(&String.to_integer/1)
    |> Enum.map(&fuel_for_mass/1)
    |> Enum.map(&add_fuel_for_fuel/1)
    |> Enum.sum()
  end

  def add_fuel_for_fuel(adding, total \\ 0) when adding > 5 do
    IO.puts "add_fuel adding=#{adding} total=#{total}"
    extra = fuel_for_mass(adding)
    add_fuel_for_fuel(extra, total+adding)
  end
  def add_fuel_for_fuel(adding, total), do: total+adding
end



case System.argv do
  ["--test"] -> ExUnit.start()
    defmodule Day1Test do
      use ExUnit.Case

      import Day1

      test "initial fuel" do
        assert Day1.fuel("""
          7
          8
          9
          """) == 1
      end
      test "total fuel" do
        assert Day1.total_fuel("""
          100756
          """) == 50346
      end
      test "total fuel 1969" do
        assert Day1.total_fuel("""
          1969
          """) == 966
      end
    end
  [input_file] -> Day1.fuel(File.read!(input_file))|> IO.inspect(label: "init")
                  Day1.total_fuel(File.read!(input_file)) |> IO.inspect(label: "total")
  _ -> IO.puts("expected --test or input_file")
    System.halt(1)
end
