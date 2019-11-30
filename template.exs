defmodule Day1 do


end

ExUnit.start()

defmodule Day1Test do
  use ExUnit.Case

  import Day1

  test "description" do
    assert f("""
      input
      """) == 3
  end
end
