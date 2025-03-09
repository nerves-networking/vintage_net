# SPDX-FileCopyrightText: 2019 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.Route.PropertiesTest do
  use ExUnit.Case

  alias VintageNet.Route.{Calculator, InterfaceInfo, Properties}

  doctest Calculator

  setup do
    # Clean up the properties we test before and after
    clear_all = fn ->
      PropertyTable.delete(VintageNet, ["available_interfaces"])
      PropertyTable.delete(VintageNet, ["connection"])
    end

    clear_all.()
    on_exit(clear_all)
  end

  test "orders available_interface by metric" do
    routes = [
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
    ]

    :ok = Properties.update_available_interfaces(routes)

    assert ["eth0", "wlan0"] == VintageNet.get(["available_interfaces"])
  end

  test "orders available_interface by metric 2" do
    routes = [
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
    ]

    :ok = Properties.update_available_interfaces(routes)

    assert ["wlan0", "eth0"] == VintageNet.get(["available_interfaces"])
  end

  test "updates best connection" do
    :ok = Properties.update_best_connection(%{})
    assert :disconnected == VintageNet.get(["connection"])

    for status <- [:lan, :internet, :disconnected] do
      interfaces = %{
        "eth0" => %InterfaceInfo{
          interface_type: :ethernet,
          status: :disconnected,
          weight: 0,
          ip_subnets: [{{192, 168, 1, 50}, 24}],
          default_gateway: {192, 168, 1, 1}
        },
        "wlan0" => %InterfaceInfo{
          interface_type: :wifi,
          status: status,
          weight: 0,
          ip_subnets: [{{192, 168, 1, 60}, 24}],
          default_gateway: {192, 168, 1, 1}
        }
      }

      :ok = Properties.update_best_connection(interfaces)

      assert status == VintageNet.get(["connection"])
    end
  end

  test "updates connection status" do
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
      },
      "usb0" => %InterfaceInfo{
        interface_type: :local,
        status: :disconnected,
        weight: 0,
        ip_subnets: [{{192, 168, 1, 70}, 24}],
        default_gateway: {192, 168, 1, 1}
      },
      "wwan0" => %InterfaceInfo{
        interface_type: :mobile,
        status: :internet,
        weight: 0,
        ip_subnets: [{{192, 168, 1, 70}, 24}],
        default_gateway: {192, 168, 1, 1}
      }
    }

    :ok = Properties.update_connection_status(interfaces)

    assert :lan == VintageNet.get(["interface", "eth0", "connection"])
    assert :internet == VintageNet.get(["interface", "wlan0", "connection"])
    assert :disconnected == VintageNet.get(["interface", "usb0", "connection"])
    assert :internet == VintageNet.get(["interface", "wwan0", "connection"])
  end
end
