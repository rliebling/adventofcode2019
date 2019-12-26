#! /usr/bin/env elixir

defmodule Day22 do
  # @deck_size 10007
  @deck_size 119_315_717_514_047

  def factory_deck(deck_size), do: for(i <- 0..(deck_size - 1), do: i)

  def init(raw) do
    raw
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_deal/1)
  end

  # deal with increment 24
  # cut -6212
  # deal into new stack
  # cut 319
  def parse_deal("deal with increment " <> incr), do: {:incr, String.to_integer(incr)}
  def parse_deal("deal into new stack"), do: {:new_stack}
  def parse_deal("cut " <> cut_size), do: {:cut, String.to_integer(cut_size)}

  def part1(deals, deck_size \\ 10007) do
    new_deal =
      Enum.reduce(deals, factory_deck(deck_size), &deal(&1, &2, deck_size))
      |> IO.inspect()

    IO.puts("part1 at 2020 #{Enum.at(new_deal, 2020)}")
    IO.puts("part1 at 0 #{Enum.at(new_deal, 0)}")
    IO.puts("part1 at 4284 #{Enum.at(new_deal, 4284)}")
    new_deal |> Enum.with_index() |> Enum.find(&(elem(&1, 0) == 2019))
  end

  def deal({:new_stack}, deck, _deck_size) do
    Enum.reverse(deck)
  end

  def deal({:cut, size}, deck, deck_size) when size < 0,
    do: deal({:cut, deck_size + size}, deck, deck_size)

  def deal({:cut, size}, deck, _deck_size) when size > 0 do
    {top, bottom} = Enum.split(deck, size)
    bottom ++ top
  end

  def deal({:incr, incr}, deck, deck_size) do
    posn_holds_which =
      for(i <- 0..(deck_size - 1), do: {rem(i * incr, deck_size), i}) |> Map.new()

    # IO.inspect(posn_holds_which, label: "posn_holds_which")

    map_deck =
      deck
      |> Enum.map_reduce(0, fn x, acc ->
        {{acc, x}, acc + 1}
      end)
      |> elem(0)
      |> Map.new()

    for posn <- 0..(deck_size - 1), do: Map.get(map_deck, posn_holds_which[posn])
  end

  def part2(instrs, deck_size, limit \\ 100) do
    # factory deck
    init_f = fn pos -> pos end

    new_f = Enum.reduce(instrs, init_f, &f_deal(&1, &2, limit))

    {first, repeat} =
      Stream.iterate(2020, &new_f.(&1))
      |> Enum.reduce_while(%{seen: %{}, count: 0}, fn pos, %{seen: seen, count: count} ->
        if rem(count, 10000) == 0, do: IO.puts("at count #{count} #{Map.size(seen)}")

        case Map.has_key?(seen, pos) do
          true -> {:halt, {seen[pos], count}}
          false -> {:cont, %{seen: Map.put(seen, pos, count), count: count + 1}}
        end
      end)

    Enum.reduce(1..10006, 2020, &(new_f.(&2) + &1 - &1)) |> IO.inspect(label: "10006 repetitions")

    Enum.reduce(1..20012, 2020, &(new_f.(&2) + &1 - &1))
    |> IO.inspect(label: "2*10006 repetitions")

    r = rem(limit, 10006)

    Enum.reduce(1..r, 2020, &(new_f.(&2) + &1 - &1))
    |> IO.inspect(label: "#{r} repetitions limit #{limit}")

    # |> Stream.drop(limit - 1)
    # |> Enum.take(1)
    # |> hd

    # IO.puts("first f at 4284 #{new_f.(4284)}")
    # IO.puts("first at 2020: #{val} ")
  end

  # the plan is to not actually deal the deck, instead to compose functions that define
  # the card at a given position and time - where time is iteration and step in the instrs
  def part2a(instrs, deck_size, limit \\ 100) do
    # factory deck
    init_f = fn pos -> pos end

    # new_f = Enum.reduce(instrs, init_f, &f_deal(&1, &2, 10007))
    # val = new_f.(2020)
    # IO.puts("first f at 4284 #{new_f.(4284)}")
    # IO.puts("first at 2020: #{val} ")

    f =
      Stream.iterate(%{seen: %{}, count: 1, f: init_f, done: false}, fn %{
                                                                          seen: seen,
                                                                          count: count,
                                                                          f: f
                                                                        } = s ->
        # IO.puts("earlier f at 2020 #{f.(2020)}")
        # IO.puts("earlier f at 4284 #{f.(4284)}")
        new_f = Enum.reduce(instrs, f, &f_deal(&1, &2, deck_size))
        val = new_f.(2020)
        IO.puts("at 2020: #{val} at #{count}")
        done = Map.has_key?(seen, val)
        seen = Map.put(seen, val, count)
        %{seen: seen, count: count + 1, f: new_f, done: done}
      end)
      |> Enum.reduce_while(nil, fn
        %{count: ^limit} = s, acc -> {:halt, s}
        %{done: true} = s, acc -> {:halt, s}
        %{done: false} = s, acc -> {:cont, s}
      end)
      |> Map.get(:f)

    f.(2020)
  end

  def f_deal({:new_stack}, f_deck, deck_size) do
    fn pos -> f_deck.(deck_size - pos - 1) end
  end

  def f_deal({:cut, size}, f_deck, deck_size) when size < 0,
    do: f_deal({:cut, deck_size + size}, f_deck, deck_size)

  def f_deal({:cut, size}, f_deck, deck_size) when size > 0 do
    fn pos -> f_deck.(rem(pos + size, deck_size)) end
  end

  def f_deal({:incr, incr}, f_deck, deck_size) do
    # a = rem(deck_size, incr)
    # rem(k * deck_size + pos, incr) == 0
    fn pos ->
      # b = rem(pos, incr)
      k = Enum.find(0..(incr - 1), &(rem(&1 * deck_size + pos, incr) == 0))
      f_deck.(div(k * deck_size + pos, incr))
    end
  end
end

defmodule Modular do
  def extended_gcd(a, b) do
    {last_remainder, last_x} = extended_gcd(abs(a), abs(b), 1, 0, 0, 1)
    {last_remainder, last_x * if(a < 0, do: -1, else: 1)}
  end

  defp extended_gcd(last_remainder, 0, last_x, _, _, _), do: {last_remainder, last_x}

  defp extended_gcd(last_remainder, remainder, last_x, x, last_y, y) do
    quotient = div(last_remainder, remainder)
    remainder2 = rem(last_remainder, remainder)
    extended_gcd(remainder, remainder2, x, last_x - quotient * x, y, last_y - quotient * y)
  end

  def inverse(e, et) do
    {g, x} = extended_gcd(e, et)
    if g != 1, do: raise("The maths are broken!")
    rem(x + et, et)
  end
end

case System.argv() do
  ["--test"] ->
    ExUnit.start()

    defmodule Day22Test do
      use ExUnit.Case

      test "incr deal" do
        deck = Day22.factory_deck(10007)
        assert Day22.deal({:incr, 1}, deck, 10007) == deck
      end

      test "f_deal incr on 10007" do
        deck_size = 10007
        init_f = fn pos -> pos end
        assert Day22.f_deal({:incr, 1}, init_f, deck_size).(2020) == 2020
      end

      test "f_deal new_stack" do
        deck_size = 10
        init_f = fn pos -> pos end
        f = Day22.f_deal({:new_stack}, init_f, deck_size)

        for(i <- 0..9, do: f.(i))
        |> IO.inspect(label: "newstack")

        assert f.(4) == 5
      end

      test "f_deal cut 3 on 10" do
        deck_size = 10
        init_f = fn pos -> pos end
        assert Day22.f_deal({:cut, 3}, init_f, deck_size).(4) == 7
      end

      test "f_deal cut -4 on 10" do
        deck_size = 10
        init_f = fn pos -> pos end

        for(i <- 0..9, do: Day22.f_deal({:cut, -4}, init_f, deck_size).(i))
        |> IO.inspect(label: "cut -4")

        assert Day22.f_deal({:cut, -4}, init_f, deck_size).(4) == 0
      end

      test "f_deal incr 3 on 10" do
        deck_size = 10
        init_f = fn pos -> pos end

        for(i <- 0..9, do: Day22.f_deal({:incr, 3}, init_f, deck_size).(i))
        |> IO.inspect(label: "incr 3")

        assert Day22.f_deal({:incr, 3}, init_f, deck_size).(4) == 8
      end

      test "f_deal incr 3 then cut 4 on 10" do
        deck_size = 10
        init_f = fn pos -> pos end

        f1 = Day22.f_deal({:incr, 3}, init_f, deck_size)
        f2 = Day22.f_deal({:cut, 4}, f1, deck_size)

        for(i <- 0..9, do: f2.(i))
        |> IO.inspect(label: "incr 3 then cut 4")

        assert f2.(4) == 6
      end

      test "part2 on 10007 " do
        inp = Day22.init(File.read!("day22.input.txt"))
        assert Day22.part2(inp, 10007, 1) == 7342
      end
    end

  [input_file] ->
    inp = Day22.init(File.read!(input_file))

    Day22.part1(inp, 10007) |> IO.inspect(label: "part1")

    Day22.part2(inp, 119_315_717_514_047, 101_741_582_076_661) |> IO.inspect(label: "part2")

  _ ->
    IO.puts("expected --test or input_file")
    #    System.halt(1)
end
