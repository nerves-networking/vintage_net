defmodule VintageNet.Connectivity.DNSResolverTest do
  use ExUnit.Case, async: true

  import VintageNet.Connectivity.DNSResolver, only: [hostent: 1]
  alias VintageNet.Connectivity.DNSResolver

  test "resolves domain name to ip address" do
    {:ok, hostent(h_addr_list: ips)} = DNSResolver.resolve("localhost")

    for ip <- ips do
      assert {_, _, _, _} = ip
    end
  end

  test "handles when IPv4 address" do
    ip = {1, 1, 1, 1}
    assert {:ok, hostent(h_addr_list: [^ip])} = DNSResolver.resolve(ip)
  end
end
