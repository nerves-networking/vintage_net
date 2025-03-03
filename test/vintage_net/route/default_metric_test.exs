# SPDX-FileCopyrightText: 2021 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.Route.DefaultMetricTest do
  use ExUnit.Case

  alias VintageNet.Route.{DefaultMetric, InterfaceInfo}

  doctest DefaultMetric

  defp compute_metric(type, status, weight) do
    # Metric computation currently doesn't look at default_gateway
    # or ip_subnets
    info = %InterfaceInfo{
      default_gateway: nil,
      weight: weight,
      ip_subnets: [],
      interface_type: type,
      status: status
    }

    DefaultMetric.compute_metric("bogus#{weight}", info)
  end

  test "disconnected interfaces classify as disabled" do
    assert :disabled == compute_metric(:ethernet, :disconnected, 0)

    assert :disabled == compute_metric(:wifi, :disconnected, 0)

    assert :disabled == compute_metric(:mobile, :disconnected, 0)
  end

  test "priorities go from wired to wireless to lte and other" do
    for status <- [:internet, :lan] do
      wired = compute_metric(:ethernet, status, 0)
      wireless = compute_metric(:wifi, status, 0)
      lte = compute_metric(:mobile, status, 0)
      other = compute_metric(:unknown, status, 0)

      assert wired < wireless
      assert wireless < lte
      assert lte < other
    end
  end

  test "internet is better than lan" do
    for ifname <- [:ethernet, :wifi, :mobile, :unknown] do
      internet = compute_metric(ifname, :internet, 0)
      lan = compute_metric(ifname, :lan, 0)

      assert internet < lan
    end
  end
end
