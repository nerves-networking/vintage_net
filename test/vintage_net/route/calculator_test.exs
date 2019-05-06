defmodule VintageNet.Route.CalculatorTest do
  use ExUnit.Case

  alias VintageNet.Route.{Calculator, InterfaceInfo}
  alias VintageNet.Interface.Classification

  doctest Calculator

  test "no interfaces" do
    prioritization = Classification.default_prioritization()
    state = Calculator.init()

    assert {%{}, []} == Calculator.compute(state, %{}, prioritization)
  end

  test "one interface" do
    prioritization = Classification.default_prioritization()
    state = Calculator.init()

    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :internet,
        addresses: [{192, 168, 1, 50}],
        default_gateway: {192, 168, 1, 1}
      }
    }

    assert {%{"eth0" => 100},
            [
              {:rule, 100, {192, 168, 1, 50}},
              {:default_route, "eth0", {192, 168, 1, 1}, 0, 100},
              {:default_route, "eth0", {192, 168, 1, 1}, 10, :main}
            ]} == Calculator.compute(state, interfaces, prioritization)
  end

  test "interface w/o addresses" do
    prioritization = Classification.default_prioritization()
    state = Calculator.init()

    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :lan,
        addresses: [],
        default_gateway: {192, 168, 1, 1}
      }
    }

    assert {%{"eth0" => 100}, []} == Calculator.compute(state, interfaces, prioritization)
  end

  test "interface w/o default gateway" do
    prioritization = Classification.default_prioritization()
    state = Calculator.init()

    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :lan,
        addresses: [{192, 168, 1, 50}],
        default_gateway: nil
      }
    }

    assert {%{"eth0" => 100}, [{:rule, 100, {192, 168, 1, 50}}]} ==
             Calculator.compute(state, interfaces, prioritization)
  end

  test "two interfaces" do
    prioritization = Classification.default_prioritization()
    state = Calculator.init()

    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :internet,
        addresses: [{192, 168, 1, 50}],
        default_gateway: {192, 168, 1, 1}
      },
      "wlan0" => %InterfaceInfo{
        interface_type: :wifi,
        status: :internet,
        addresses: [{192, 168, 1, 60}],
        default_gateway: {192, 168, 1, 1}
      }
    }

    assert {%{"eth0" => 100, "wlan0" => 101},
            [
              {:rule, 100, {192, 168, 1, 50}},
              {:rule, 101, {192, 168, 1, 60}},
              {:default_route, "eth0", {192, 168, 1, 1}, 0, 100},
              {:default_route, "eth0", {192, 168, 1, 1}, 10, :main},
              {:default_route, "wlan0", {192, 168, 1, 1}, 0, 101},
              {:default_route, "wlan0", {192, 168, 1, 1}, 20, :main}
            ]} == Calculator.compute(state, interfaces, prioritization)
  end

  test "one interface and many addresses" do
    prioritization = Classification.default_prioritization()
    state = Calculator.init()

    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :internet,
        addresses: [{192, 168, 1, 50}, {192, 168, 1, 51}, {192, 168, 1, 52}],
        default_gateway: {192, 168, 1, 1}
      }
    }

    assert {%{"eth0" => 100},
            [
              {:rule, 100, {192, 168, 1, 50}},
              {:rule, 100, {192, 168, 1, 51}},
              {:rule, 100, {192, 168, 1, 52}},
              {:default_route, "eth0", {192, 168, 1, 1}, 0, 100},
              {:default_route, "eth0", {192, 168, 1, 1}, 10, :main}
            ]} == Calculator.compute(state, interfaces, prioritization)
  end
end
