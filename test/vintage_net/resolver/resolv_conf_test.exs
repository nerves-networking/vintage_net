defmodule VintageNet.Resolver.ResolvConfTest do
  use VintageNetTest.Case
  alias VintageNet.Resolver.ResolvConf

  # Helper to flatten return value
  defp to_resolvconf(map) do
    map
    |> ResolvConf.to_config()
    |> IO.iodata_to_binary()
  end

  test "empty resolvconf is empty" do
    assert to_resolvconf(%{}) == ""
  end

  test "one interface" do
    input = %{
      "eth0" => %{domain: "example.com", name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]}
    }

    output = """
    search example.com
    nameserver 1.1.1.1
    nameserver 8.8.8.8
    """

    assert to_resolvconf(input) == output
  end

  test "two interface" do
    input = %{
      "eth0" => %{domain: "example.com", name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]},
      "wlan0" => %{domain: "example2.com", name_servers: [{1, 1, 1, 2}, {8, 8, 8, 9}]}
    }

    output = """
    search example.com
    search example2.com
    nameserver 1.1.1.1
    nameserver 8.8.8.8
    nameserver 1.1.1.2
    nameserver 8.8.8.9
    """

    assert to_resolvconf(input) == output
  end

  test "no search domain" do
    input = %{
      "eth0" => %{domain: nil, name_servers: [{1, 1, 1, 1}, {8, 8, 8, 8}]}
    }

    output = """
    nameserver 1.1.1.1
    nameserver 8.8.8.8
    """

    assert to_resolvconf(input) == output
  end
end
