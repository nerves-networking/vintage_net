defmodule VintageNet.Connectivity.TCPPingTest do
  use ExUnit.Case, async: true

  alias VintageNet.Connectivity.TCPPing
  alias VintageNetTest.Utils

  test "ping IPv4 known hosts" do
    ifname = Utils.get_ifname_for_tests()

    assert TCPPing.ping(ifname, {"localhost", "127.0.0.1", 80}) == :ok
    assert TCPPing.ping(ifname, {"1.1.1.1", "1.1.1.1", 53}) == :ok
  end

  # If this fails and your LAN doesn't support IPv6, run "mix test --exclude requires_ipv6"
  @tag :requires_ipv6
  test "ping IPv6 known hosts" do
    ifname = Utils.get_ifname_for_tests()

    assert TCPPing.ping(ifname, {"localhost", "::1", 80}) == :ok
    assert TCPPing.ping(ifname, {"1.1.1.1", "2606:4700:4700::1111", 53}) == :ok
  end

  test "ping internet_host_list" do
    ifname = Utils.get_ifname_for_tests()

    # While these won't work for everyone, they should work on CI
    for {host, port} <- Application.fetch_env!(:vintage_net, :internet_host_list) do
      assert TCPPing.ping(ifname, {"", host, port}) == :ok
    end
  end

  test "ping IP addresses that shouldn't work" do
    ifname = Utils.get_ifname_for_tests()

    # This IP address is in a reserved IP range and shouldn't work
    assert TCPPing.ping(ifname, {"", "192.0.2.254", 80}) == {:error, :timeout}
  end

  test "ping with verify callback" do
    ifname = Utils.get_ifname_for_tests()

    # for this test, we need to actually be listening on a port
    {:ok, socket} =
      :gen_tcp.listen(0, [
        :binary,
        {:ip, {127, 0, 0, 1}},
        {:packet, :line},
        {:active, false},
        {:reuseaddr, true}
      ])

    {:ok, port} = :inet.port(socket)

    spawn_link(fn ->
      {:ok, client} = :gen_tcp.accept(socket, 1000)
      :gen_tcp.send(client, "hello world\n")
      :gen_tcp.shutdown(client, :read_write)

      {:ok, client} = :gen_tcp.accept(socket, 1000)
      :gen_tcp.send(client, "goodbye world\n")
      :gen_tcp.shutdown(client, :read_write)
    end)

    verify_fun = fn _, _, _ ->
      receive do
        {:tcp, _port, 'hello world\n'} -> true
        _ -> false
      end
    end

    assert TCPPing.ping(ifname, {"localhost", "127.0.0.1", port}, verify_fun) == :ok

    assert TCPPing.ping(ifname, {"localhost", "127.0.0.1", port}, verify_fun) ==
             {:error, :verify_failed}

    :gen_tcp.close(socket)
  end
end
