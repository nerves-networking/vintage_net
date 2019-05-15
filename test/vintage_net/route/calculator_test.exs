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
        ip_subnets: [{{192, 168, 1, 50}, 24}],
        default_gateway: {192, 168, 1, 1}
      }
    }

    assert {%{"eth0" => 100},
            [
              {:local_route, "eth0", {192, 168, 1, 50}, 24, 10},
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
        ip_subnets: [],
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
        ip_subnets: [{{192, 168, 1, 50}, 24}],
        default_gateway: nil
      }
    }

    assert {%{"eth0" => 100},
            [{:local_route, "eth0", {192, 168, 1, 50}, 24, 50}, {:rule, 100, {192, 168, 1, 50}}]} ==
             Calculator.compute(state, interfaces, prioritization)
  end

  test "two interfaces, both internet" do
    prioritization = Classification.default_prioritization()
    state = Calculator.init()

    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :internet,
        ip_subnets: [{{192, 168, 1, 50}, 24}],
        default_gateway: {192, 168, 1, 1}
      },
      "wlan0" => %InterfaceInfo{
        interface_type: :wifi,
        status: :internet,
        ip_subnets: [{{192, 168, 1, 60}, 24}],
        default_gateway: {192, 168, 1, 1}
      }
    }

    assert {%{"eth0" => 100, "wlan0" => 101},
            [
              {:local_route, "eth0", {192, 168, 1, 50}, 24, 10},
              {:local_route, "wlan0", {192, 168, 1, 60}, 24, 20},
              {:rule, 100, {192, 168, 1, 50}},
              {:rule, 101, {192, 168, 1, 60}},
              {:default_route, "eth0", {192, 168, 1, 1}, 0, 100},
              {:default_route, "eth0", {192, 168, 1, 1}, 10, :main},
              {:default_route, "wlan0", {192, 168, 1, 1}, 0, 101},
              {:default_route, "wlan0", {192, 168, 1, 1}, 20, :main}
            ]} == Calculator.compute(state, interfaces, prioritization)
  end

  test "two interfaces, bad ethernet" do
    prioritization = Classification.default_prioritization()
    state = Calculator.init()

    interfaces = %{
      "eth0" => %InterfaceInfo{
        interface_type: :ethernet,
        status: :lan,
        ip_subnets: [{{192, 168, 1, 50}, 24}],
        default_gateway: {192, 168, 1, 1}
      },
      "wlan0" => %InterfaceInfo{
        interface_type: :wifi,
        status: :internet,
        ip_subnets: [{{192, 168, 1, 60}, 24}],
        default_gateway: {192, 168, 1, 1}
      }
    }

    assert {%{"eth0" => 100, "wlan0" => 101},
            [
              {:local_route, "eth0", {192, 168, 1, 50}, 24, 50},
              {:local_route, "wlan0", {192, 168, 1, 60}, 24, 20},
              {:rule, 100, {192, 168, 1, 50}},
              {:rule, 101, {192, 168, 1, 60}},
              {:default_route, "eth0", {192, 168, 1, 1}, 0, 100},
              {:default_route, "eth0", {192, 168, 1, 1}, 50, :main},
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
              {:local_route, "eth0", {192, 168, 1, 50}, 24, 10},
              {:rule, 100, {192, 168, 1, 50}},
              {:rule, 100, {192, 168, 1, 51}},
              {:rule, 100, {192, 168, 1, 52}},
              {:default_route, "eth0", {192, 168, 1, 1}, 0, 100},
              {:default_route, "eth0", {192, 168, 1, 1}, 10, :main}
            ]} == Calculator.compute(state, interfaces, prioritization)
  end
end
