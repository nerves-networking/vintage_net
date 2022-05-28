defmodule VintageNet.Resolver.ResolvConfTest do
  use VintageNetTest.Case
  alias VintageNet.Resolver.ResolvConf

  # Helper to flatten return value
  defp to_resolvconf(map, additional_name_servers \\ []) do
    map
    |> ResolvConf.to_config(additional_name_servers)
    |> IO.iodata_to_binary()
  end

  test "empty resolvconf is empty" do
    assert to_resolvconf(%{}) == "# This file is managed by VintageNet. Do not edit.\n\n"
  end

  test "one interface" do
    input = %{
      "eth0" => %{domain: "example.com", name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]}
    }

    output = """
    # This file is managed by VintageNet. Do not edit.

    search example.com # From eth0
    nameserver 1.1.1.1 # From eth0
    nameserver 8.8.8.8 # From eth0
    """

    assert to_resolvconf(input) == output
  end

  test "two interfaces" do
    input = %{
      "eth0" => %{domain: "example.com", name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]},
      "wlan0" => %{domain: "example2.com", name_servers: [{1, 1, 1, 2}, {8, 8, 8, 9}]}
    }

    output = """
    # This file is managed by VintageNet. Do not edit.

    search example.com # From eth0
    search example2.com # From wlan0
    nameserver 1.1.1.1 # From eth0
    nameserver 1.1.1.2 # From wlan0
    nameserver 8.8.8.8 # From eth0
    nameserver 8.8.8.9 # From wlan0
    """

    assert to_resolvconf(input) == output
  end

  test "no search domain" do
    input = %{
      "eth0" => %{domain: nil, name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]}
    }

    output = """
    # This file is managed by VintageNet. Do not edit.

    nameserver 1.1.1.1 # From eth0
    nameserver 8.8.8.8 # From eth0
    """

    assert to_resolvconf(input) == output
  end

  test "empty search domain" do
    input = %{
      "eth0" => %{domain: "", name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]}
    }

    output = """
    # This file is managed by VintageNet. Do not edit.

    nameserver 1.1.1.1 # From eth0
    nameserver 8.8.8.8 # From eth0
    """

    assert to_resolvconf(input) == output
  end

  test "pruning redundant entries" do
    input = %{
      "eth0" => %{domain: "example.com", name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]},
      "eth1" => %{domain: "aaa-in-between.com", name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]},
      "wlan0" => %{domain: "example.com", name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]}
    }

    output = """
    # This file is managed by VintageNet. Do not edit.

    search aaa-in-between.com # From eth1
    search example.com # From wlan0,eth0
    nameserver 1.1.1.1 # From eth0,eth1,wlan0
    nameserver 8.8.8.8 # From eth0,eth1,wlan0
    """

    assert to_resolvconf(input) == output
  end

  test "multiple interface uniqueness" do
    input = %{
      "eth0" => %{domain: "example.com", name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]},
      "wlan0" => %{domain: "example.com", name_servers: [{8, 8, 4, 4}, {1, 1, 1, 1}]}
    }

    output = """
    # This file is managed by VintageNet. Do not edit.

    search example.com # From wlan0,eth0
    nameserver 1.1.1.1 # From eth0,wlan0
    nameserver 8.8.4.4 # From wlan0
    nameserver 8.8.8.8 # From eth0
    """

    assert to_resolvconf(input) == output
  end

  test "additional name servers" do
    input = %{
      "eth0" => %{domain: "example.com", name_servers: [{8, 8, 8, 8}, {1, 1, 1, 1}]}
    }

    output = """
    # This file is managed by VintageNet. Do not edit.

    search example.com # From eth0
    nameserver 1.1.1.1 # From global,eth0
    nameserver 8.8.4.4 # From global
    nameserver 8.8.8.8 # From eth0
    """

    assert to_resolvconf(input, [{1, 1, 1, 1}, {8, 8, 4, 4}]) == output
  end

  test "global name servers are always first" do
    additional_name_servers = [{8, 8, 8, 8}, {1, 1, 1, 1}]

    input = %{
      "eth0" => %{name_servers: [{4, 4, 4, 4}, {3, 3, 3, 3}, {8, 8, 8, 8}]},
      "eth1" => %{name_servers: [{4, 4, 4, 4}, {1, 1, 1, 1}, {2, 2, 2, 2}]}
    }

    output = """
    # This file is managed by VintageNet. Do not edit.

    nameserver 8.8.8.8 # From global,eth0
    nameserver 1.1.1.1 # From global,eth1
    nameserver 4.4.4.4 # From eth0,eth1
    nameserver 2.2.2.2 # From eth1
    nameserver 3.3.3.3 # From eth0
    """

    assert to_resolvconf(input, additional_name_servers) == output
  end

  test "to_name_server_list/2" do
    additional_name_servers = [{8, 8, 8, 8}, {1, 1, 1, 1}]

    input = %{
      "eth0" => %{name_servers: [{4, 4, 4, 4}, {3, 3, 3, 3}, {8, 8, 8, 8}]},
      "eth1" => %{name_servers: [{4, 4, 4, 4}, {1, 1, 1, 1}, {2, 2, 2, 2}]}
    }

    output = [
      %{address: {8, 8, 8, 8}, from: [:global, "eth0"]},
      %{address: {1, 1, 1, 1}, from: [:global, "eth1"]},
      %{address: {4, 4, 4, 4}, from: ["eth0", "eth1"]},
      %{address: {2, 2, 2, 2}, from: ["eth1"]},
      %{address: {3, 3, 3, 3}, from: ["eth0"]}
    ]

    assert ResolvConf.to_name_server_list(input, additional_name_servers) == output
  end
end
