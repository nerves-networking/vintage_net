defmodule VintageNet.Interface.ClassificationTest do
  use ExUnit.Case

  alias VintageNet.Interface.Classification

  doctest Classification

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
