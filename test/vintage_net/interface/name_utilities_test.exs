defmodule VintageNet.Interface.NameUtilitiesTest do
  use ExUnit.Case

  alias VintageNet.Interface.NameUtilities

  doctest NameUtilities

  test "that to_type works" do
    assert NameUtilities.to_type("eth0") == :ethernet
    assert NameUtilities.to_type("eth1") == :ethernet
    assert NameUtilities.to_type("en0") == :ethernet
    assert NameUtilities.to_type("enp6s0") == :ethernet
    assert NameUtilities.to_type("wlan0") == :wifi
    assert NameUtilities.to_type("wlan1") == :wifi
    assert NameUtilities.to_type("ppp0") == :mobile
    assert NameUtilities.to_type("wwan0") == :mobile
    assert NameUtilities.to_type("lo") == :local
    assert NameUtilities.to_type("something0") == :unknown
  end

  test "that to_instance works" do
    assert NameUtilities.get_instance("eth0") == 0
    assert NameUtilities.get_instance("eth1") == 1
    assert NameUtilities.get_instance("en3") == 3
    assert NameUtilities.get_instance("enp6s0") == 60
    assert NameUtilities.get_instance("wlan0") == 0
    assert NameUtilities.get_instance("wlan1") == 1
    assert NameUtilities.get_instance("ppp0") == 0
    assert NameUtilities.get_instance("something5") == 5
  end
end
