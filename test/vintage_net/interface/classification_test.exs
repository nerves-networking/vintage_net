defmodule VintageNet.Interface.ClassificationTest do
  use ExUnit.Case

  alias VintageNet.Interface.Classification

  doctest Classification

  test "that to_type works" do
    assert Classification.to_type("eth0") == :ethernet
    assert Classification.to_type("eth1") == :ethernet
    assert Classification.to_type("en0") == :ethernet
    assert Classification.to_type("enp6s0") == :ethernet
    assert Classification.to_type("wlan0") == :wifi
    assert Classification.to_type("wlan1") == :wifi
    assert Classification.to_type("ppp0") == :mobile
    assert Classification.to_type("something0") == :unknown
  end

  test "that to_instance works" do
    assert Classification.to_instance("eth0") == 0
    assert Classification.to_instance("eth1") == 1
    assert Classification.to_instance("en3") == 3
    assert Classification.to_instance("enp6s0") == 60
    assert Classification.to_instance("wlan0") == 0
    assert Classification.to_instance("wlan1") == 1
    assert Classification.to_instance("ppp0") == 0
    assert Classification.to_instance("something5") == 5
  end

  test "disconnected interfaces classify as disabled" do
    priors = Classification.default_prioritization()

    assert :disabled ==
             Classification.compute_metric(:ethernet, :disconnected, 0, priors)

    assert :disabled ==
             Classification.compute_metric(:wifi, :disconnected, 0, priors)

    assert :disabled ==
             Classification.compute_metric(:mobile, :disconnected, 0, priors)
  end

  test "priorities go from wired to wireless to lte and other" do
    priors = Classification.default_prioritization()

    for status <- [:internet, :lan] do
      wired = Classification.compute_metric(:ethernet, status, 0, priors)
      wireless = Classification.compute_metric(:wifi, status, 0, priors)
      lte = Classification.compute_metric(:mobile, status, 0, priors)
      other = Classification.compute_metric(:unknown, status, 0, priors)

      assert wired < wireless
      assert wireless < lte
      assert lte < other
    end
  end

  test "internet is better than lan" do
    priors = Classification.default_prioritization()

    for ifname <- [:ethernet, :wifi, :mobile, :unknown] do
      internet = Classification.compute_metric(ifname, :internet, 0, priors)
      lan = Classification.compute_metric(ifname, :lan, 0, priors)

      assert internet < lan
    end
  end
end
