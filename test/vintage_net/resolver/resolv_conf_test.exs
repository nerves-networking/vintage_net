# SPDX-FileCopyrightText: 2020 Frank Hunleth
# SPDX-FileCopyrightText: 2021 Connor Rigby
# SPDX-FileCopyrightText: 2022 Masatoshi Nishiguchi
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.Resolver.ResolvConfTest do
  use VintageNetTest.Case
  import ExUnit.CaptureLog
  alias VintageNet.Resolver.ResolvConf

  # Helper to flatten return value
  defp to_resolvconf(map, additional_name_servers \\ []) do
    map
    |> ResolvConf.to_config(additional_name_servers)
    |> IO.chardata_to_string()
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

    # From eth0
    search example.com
    # From eth0
    nameserver 1.1.1.1
    # From eth0
    nameserver 8.8.8.8
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

    # From eth0
    search example.com
    # From wlan0
    search example2.com
    # From eth0
    nameserver 1.1.1.1
    # From wlan0
    nameserver 1.1.1.2
    # From eth0
    nameserver 8.8.8.8
    # From wlan0
    nameserver 8.8.8.9
    """

    assert to_resolvconf(input) == output
  end

  test "no search domain" do
    input = %{
      "eth0" => %{domain: nil, name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]}
    }

    output = """
    # This file is managed by VintageNet. Do not edit.

    # From eth0
    nameserver 1.1.1.1
    # From eth0
    nameserver 8.8.8.8
    """

    assert to_resolvconf(input) == output
  end

  test "empty search domain" do
    input = %{
      "eth0" => %{domain: "", name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]}
    }

    output = """
    # This file is managed by VintageNet. Do not edit.

    # From eth0
    nameserver 1.1.1.1
    # From eth0
    nameserver 8.8.8.8
    """

    assert to_resolvconf(input) == output
  end

  test "valid search lists and trailing dots" do
    input = %{
      "eth0" => %{
        domain: " example.com   internal.example. ",
        name_servers: [{1, 1, 1, 1}]
      }
    }

    assert to_resolvconf(input) =~ "search example.com internal.example.\n"
  end

  test "unsafe search domains cannot inject resolv.conf directives" do
    input = %{
      "wlan0" => %{
        domain: "evil.example.com\nnameserver 203.0.113.7\noptions rotate\n#",
        name_servers: [{1, 1, 1, 1}]
      }
    }

    log =
      capture_log(fn ->
        assert to_resolvconf(input) == """
               # This file is managed by VintageNet. Do not edit.

               # From wlan0
               nameserver 1.1.1.1
               """
      end)

    assert log =~ "Ignoring unsafe DNS search domain from \"wlan0\""
  end

  test "oversized search domains are ignored" do
    input = %{
      "wlan0" => %{
        domain: String.duplicate("a", 256),
        name_servers: [{1, 1, 1, 1}]
      }
    }

    capture_log(fn ->
      refute to_resolvconf(input) =~ "search "
    end)
  end

  test "control characters in interface names cannot inject resolv.conf directives" do
    input = %{
      "eth0\nnameserver 203.0.113.7" => %{
        domain: "example.com",
        name_servers: [{1, 1, 1, 1}]
      }
    }

    output = to_resolvconf(input)

    refute output =~ "\nnameserver 203.0.113.7\n"
    assert output =~ "# From eth0?nameserver 203.0.113.7\n"
  end

  test "pruning redundant entries" do
    input = %{
      "eth0" => %{domain: "example.com", name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]},
      "eth1" => %{domain: "aaa-in-between.com", name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]},
      "wlan0" => %{domain: "example.com", name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]}
    }

    output = """
    # This file is managed by VintageNet. Do not edit.

    # From eth1
    search aaa-in-between.com
    # From wlan0,eth0
    search example.com
    # From eth0,eth1,wlan0
    nameserver 1.1.1.1
    # From eth0,eth1,wlan0
    nameserver 8.8.8.8
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

    # From wlan0,eth0
    search example.com
    # From eth0,wlan0
    nameserver 1.1.1.1
    # From wlan0
    nameserver 8.8.4.4
    # From eth0
    nameserver 8.8.8.8
    """

    assert to_resolvconf(input) == output
  end

  test "additional name servers" do
    input = %{
      "eth0" => %{domain: "example.com", name_servers: [{8, 8, 8, 8}, {1, 1, 1, 1}]}
    }

    output = """
    # This file is managed by VintageNet. Do not edit.

    # From eth0
    search example.com
    # From global,eth0
    nameserver 1.1.1.1
    # From global
    nameserver 8.8.4.4
    # From eth0
    nameserver 8.8.8.8
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

    # From global,eth0
    nameserver 8.8.8.8
    # From global,eth1
    nameserver 1.1.1.1
    # From eth0,eth1
    nameserver 4.4.4.4
    # From eth1
    nameserver 2.2.2.2
    # From eth0
    nameserver 3.3.3.3
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
