# SPDX-FileCopyrightText: 2019 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.Route.CalculatorTest do
  use ExUnit.Case

  alias VintageNet.Route.{Calculator, DefaultMetric, InterfaceInfo}

  doctest Calculator

  defp compute(state, interfaces) do
    Calculator.compute(state, interfaces, &DefaultMetric.compute_metric/2)
  end

  test "no interfaces" do
    state = Calculator.init()

    assert {%{}, []} == compute(state, %{})
  end

  test "one interface" do
    state = Calculator.init()

    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :internet,
        weight: 0,
        ip_subnets: [{{192, 168, 1, 50}, 24}],
        default_gateway: {192, 168, 1, 1}
      }
    }

    assert {%{"eth0" => 100},
            [
              {:rule, 100, {192, 168, 1, 50}},
              {:local_route, "eth0", {192, 168, 1, 50}, 24, 0, 100},
              {:local_route, "eth0", {192, 168, 1, 50}, 24, 10, :main},
              {:default_route, "eth0", {192, 168, 1, 1}, 0, 100},
              {:default_route, "eth0", {192, 168, 1, 1}, 10, :main}
            ]} == compute(state, interfaces)
  end

  test "a disconnected interface" do
    state = Calculator.init()

    # The calculator should ignore the IP address and gateway even
    # if they're present.
    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :disconnected,
        weight: 0,
        ip_subnets: [{{192, 168, 1, 50}, 24}],
        default_gateway: {192, 168, 1, 1}
      }
    }

    assert {%{"eth0" => 100}, []} == compute(state, interfaces)
  end

  test "interface w/o addresses" do
    state = Calculator.init()

    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :lan,
        weight: 0,
        ip_subnets: [],
        default_gateway: {192, 168, 1, 1}
      }
    }

    assert {%{"eth0" => 100}, []} == compute(state, interfaces)
  end

  test "interface w/o default gateway" do
    state = Calculator.init()

    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        weight: 0,
        status: :lan,
        ip_subnets: [{{192, 168, 1, 50}, 24}],
        default_gateway: nil
      }
    }

    assert {%{"eth0" => 100},
            [
              {:rule, 100, {192, 168, 1, 50}},
              {:local_route, "eth0", {192, 168, 1, 50}, 24, 0, 100},
              {:local_route, "eth0", {192, 168, 1, 50}, 24, 50, :main}
            ]} ==
             compute(state, interfaces)
  end

  test "two interfaces, both internet" do
    state = Calculator.init()

    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :internet,
        weight: 0,
        ip_subnets: [{{192, 168, 1, 50}, 24}],
        default_gateway: {192, 168, 1, 1}
      },
      "wlan0" => %InterfaceInfo{
        interface_type: :wifi,
        status: :internet,
        weight: 0,
        ip_subnets: [{{192, 168, 1, 60}, 24}],
        default_gateway: {192, 168, 1, 1}
      }
    }

    assert {%{"eth0" => 100, "wlan0" => 101},
            [
              {:rule, 100, {192, 168, 1, 50}},
              {:rule, 101, {192, 168, 1, 60}},
              {:local_route, "eth0", {192, 168, 1, 50}, 24, 0, 100},
              {:local_route, "eth0", {192, 168, 1, 50}, 24, 10, :main},
              {:local_route, "wlan0", {192, 168, 1, 60}, 24, 0, 101},
              {:local_route, "wlan0", {192, 168, 1, 60}, 24, 20, :main},
              {:default_route, "eth0", {192, 168, 1, 1}, 0, 100},
              {:default_route, "eth0", {192, 168, 1, 1}, 10, :main},
              {:default_route, "wlan0", {192, 168, 1, 1}, 0, 101},
              {:default_route, "wlan0", {192, 168, 1, 1}, 20, :main}
            ]} == compute(state, interfaces)
  end

  test "two interfaces, bad ethernet" do
    state = Calculator.init()

    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :lan,
        weight: 0,
        ip_subnets: [{{192, 168, 1, 50}, 24}],
        default_gateway: {192, 168, 1, 1}
      },
      "wlan0" => %InterfaceInfo{
        interface_type: :wifi,
        status: :internet,
        weight: 0,
        ip_subnets: [{{192, 168, 1, 60}, 24}],
        default_gateway: {192, 168, 1, 1}
      }
    }

    assert {%{"eth0" => 100, "wlan0" => 101},
            [
              {:rule, 100, {192, 168, 1, 50}},
              {:rule, 101, {192, 168, 1, 60}},
              {:local_route, "eth0", {192, 168, 1, 50}, 24, 0, 100},
              {:local_route, "eth0", {192, 168, 1, 50}, 24, 50, :main},
              {:local_route, "wlan0", {192, 168, 1, 60}, 24, 0, 101},
              {:local_route, "wlan0", {192, 168, 1, 60}, 24, 20, :main},
              {:default_route, "eth0", {192, 168, 1, 1}, 0, 100},
              {:default_route, "eth0", {192, 168, 1, 1}, 50, :main},
              {:default_route, "wlan0", {192, 168, 1, 1}, 0, 101},
              {:default_route, "wlan0", {192, 168, 1, 1}, 20, :main}
            ]} == compute(state, interfaces)
  end

  test "one interface and many addresses" do
    state = Calculator.init()

    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :internet,
        weight: 0,
        ip_subnets: [
          {{192, 168, 1, 50}, 24},
          {{192, 168, 1, 51}, 24},
          {{192, 168, 1, 52}, 24}
        ],
        default_gateway: {192, 168, 1, 1}
      }
    }

    assert {%{"eth0" => 100},
            [
              {:rule, 100, {192, 168, 1, 50}},
              {:rule, 100, {192, 168, 1, 51}},
              {:rule, 100, {192, 168, 1, 52}},
              {:local_route, "eth0", {192, 168, 1, 50}, 24, 0, 100},
              {:local_route, "eth0", {192, 168, 1, 50}, 24, 10, :main},
              {:default_route, "eth0", {192, 168, 1, 1}, 0, 100},
              {:default_route, "eth0", {192, 168, 1, 1}, 10, :main}
            ]} == compute(state, interfaces)
  end

  test "rule table index range is as expected" do
    assert 100..107 == Calculator.rule_table_index_range()
  end

  test "multiple interfaces of the same type" do
    state = Calculator.init()

    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :internet,
        weight: 0,
        ip_subnets: [{{192, 168, 0, 10}, 24}],
        default_gateway: {192, 168, 0, 1}
      },
      "eth1" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :internet,
        weight: 1,
        ip_subnets: [{{192, 168, 1, 20}, 24}],
        default_gateway: {192, 168, 1, 1}
      },
      "eth2" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :internet,
        weight: 2,
        ip_subnets: [{{192, 168, 2, 20}, 24}],
        default_gateway: {192, 168, 2, 1}
      }
    }

    assert {%{"eth0" => 100, "eth1" => 101, "eth2" => 102},
            [
              {:rule, 100, {192, 168, 0, 10}},
              {:rule, 101, {192, 168, 1, 20}},
              {:rule, 102, {192, 168, 2, 20}},
              {:local_route, "eth0", {192, 168, 0, 10}, 24, 0, 100},
              {:local_route, "eth0", {192, 168, 0, 10}, 24, 10, :main},
              {:local_route, "eth1", {192, 168, 1, 20}, 24, 0, 101},
              {:local_route, "eth1", {192, 168, 1, 20}, 24, 11, :main},
              {:local_route, "eth2", {192, 168, 2, 20}, 24, 0, 102},
              {:local_route, "eth2", {192, 168, 2, 20}, 24, 12, :main},
              {:default_route, "eth0", {192, 168, 0, 1}, 0, 100},
              {:default_route, "eth0", {192, 168, 0, 1}, 10, :main},
              {:default_route, "eth1", {192, 168, 1, 1}, 0, 101},
              {:default_route, "eth1", {192, 168, 1, 1}, 11, :main},
              {:default_route, "eth2", {192, 168, 2, 1}, 0, 102},
              {:default_route, "eth2", {192, 168, 2, 1}, 12, :main}
            ]} == compute(state, interfaces)
  end
end
