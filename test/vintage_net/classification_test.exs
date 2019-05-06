defmodule VintageNet.Interface.ClassificationTest do
  use ExUnit.Case

  alias VintageNet.Interface.Classification

  doctest Classification

  test "that type works" do
    assert Classification.to_type("eth0") == :ethernet
    assert Classification.to_type("eth1") == :ethernet
    assert Classification.to_type("en0") == :ethernet
    assert Classification.to_type("enp6s0") == :ethernet
    assert Classification.to_type("wlan0") == :wifi
    assert Classification.to_type("wlan1") == :wifi
    assert Classification.to_type("ppp0") == :mobile
    assert Classification.to_type("something0") == :unknown
  end

  test "disabled interfaces classify as disabled" do
    assert Classification.compute_metric(
             :ethernet,
             :disabled,
             Classification.default_prioritization()
           )

    assert Classification.compute_metric(
             :wifi,
             :disabled,
             Classification.default_prioritization()
           )

    assert Classification.compute_metric(
             :mobile,
             :disabled,
             Classification.default_prioritization()
           )
  end

  test "priorities go from wired to wireless to lte and other" do
    priors = Classification.default_prioritization()

    for status <- [:internet, :lan] do
      wired = Classification.compute_metric(:ethernet, status, priors)
      wireless = Classification.compute_metric(:wifi, status, priors)
      lte = Classification.compute_metric(:mobile, status, priors)
      other = Classification.compute_metric(:unknown, status, priors)

      assert wired < wireless
      assert wireless < lte
      assert lte < other
    end
  end

  test "internet is better than lan" do
    priors = Classification.default_prioritization()

    for ifname <- [:ethernet, :wifi, :mobile, :unknown] do
      internet = Classification.compute_metric(ifname, :internet, priors)
      lan = Classification.compute_metric(ifname, :lan, priors)

      assert internet < lan
    end
  end
end
