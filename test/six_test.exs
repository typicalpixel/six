defmodule SixTest do
  use ExUnit.Case
  doctest Six

  test "greets the world" do
    assert Six.hello() == :world
  end
end
