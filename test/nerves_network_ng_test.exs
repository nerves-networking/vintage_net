defmodule NervesNetworkNGTest do
  use ExUnit.Case
  doctest Nerves.NetworkNG

  test "greets the world" do
    assert Nerves.NetworkNG.hello() == :world
  end
end
