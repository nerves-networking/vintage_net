defmodule VintageNet.Interface.ClassificationTest do
  use ExUnit.Case

  alias VintageNet.Interface.Classification

  doctest Classification

  test "disabled interfaces classify as disabled" do
    assert Classification.compute_metric(
             "eth0",
             :disabled,
             Classification.default_prioritization()
           )

    assert Classification.compute_metric(
             "wlan0",
             :disabled,
             Classification.default_prioritization()
           )

    assert Classification.compute_metric(
             "ppp0",
             :disabled,
             Classification.default_prioritization()
           )
  end

  test "priorities go from wired to wireless to lte and other" do
    priors = Classification.default_prioritization()

    for status <- [:internet, :lan] do
      wired = Classification.compute_metric("eth0", status, priors)
      wireless = Classification.compute_metric("wlan0", status, priors)
      lte = Classification.compute_metric("ppp0", status, priors)
      other = Classification.compute_metric("something0", status, priors)

      assert wired < wireless
      assert wireless < lte
      assert lte < other
    end
  end

  test "internet is better than lan" do
    priors = Classification.default_prioritization()

    for ifname <- ["eth0", "wlan0", "ppp0", "other0"] do
      internet = Classification.compute_metric(ifname, :internet, priors)
      lan = Classification.compute_metric(ifname, :lan, priors)

      assert internet < lan
    end
  end

  test "wired internet interfaces are all the same" do
    priors = Classification.default_prioritization()

    metric = Classification.compute_metric("eth0", :internet, priors)

    for ifname <- ["eth1", "en0", "enp6s0", "eth2"] do
      other_metric = Classification.compute_metric(ifname, :internet, priors)

      assert other_metric == metric
    end
  end
end
