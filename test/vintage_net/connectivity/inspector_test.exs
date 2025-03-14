# SPDX-FileCopyrightText: 2021 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.Connectivity.InspectorTest do
  use ExUnit.Case

  alias VintageNet.Connectivity.Inspector
  alias VintageNetTest.Utils

  doctest Inspector

  test "on_interface?/2" do
    if_addrs = [
      {{1, 2, 3, 4, 1234, 21943, 7498, 1443}, {65535, 65535, 65535, 65535, 0, 0, 0, 0}},
      {{192, 168, 7, 139}, {255, 255, 255, 0}}
    ]

    assert Inspector.on_interface?({192, 168, 7, 10}, if_addrs)
    refute Inspector.on_interface?({1, 1, 1, 1}, if_addrs)

    assert Inspector.on_interface?({1, 2, 3, 4, 0, 0, 0, 1}, if_addrs)
    refute Inspector.on_interface?({1, 2, 3, 10, 0, 0, 0, 1}, if_addrs)
  end

  test "routed_address?/2" do
    ifname = Utils.get_loopback_ifname()

    # Anything on 127.x.y.z should be on the LAN (aka not routed)
    refute Inspector.routed_address?(ifname, {127, 0, 0, 1})
    refute Inspector.routed_address?(ifname, {127, 0, 1, 1})
    refute Inspector.routed_address?(ifname, {127, 1, 1, 1})

    # Anything not on 127.x.y.z is off LAN (aka routed, let's pretend)
    assert Inspector.routed_address?(ifname, {128, 0, 0, 1})
    assert Inspector.routed_address?(ifname, {10, 10, 10, 10})

    # Anything on interfaces that we don't know about return false
    refute Inspector.routed_address?("bogus0", {10, 10, 10, 10})
  end

  test "finds connections using port sockets" do
    # Run a super slow HTTP request to test
    site = "whenwhere.nerves-project.org"

    {:ok, socket} = :gen_tcp.connect(to_charlist(site), 80, [:binary, {:active, false}])
    {:ok, {src_ip, _src_port}} = :inet.sockname(socket)

    # Simulate a first call. The status should be unknown, but the socket should be
    # in the cache.
    {status, cache} =
      Inspector.check_ports({:unknown, %{}}, [socket], [{src_ip, {255, 255, 255, 0}}], %{})

    assert status == :unknown
    assert Map.has_key?(cache, socket)
    # Make traffic happen on the socket
    :ok =
      :gen_tcp.send(
        socket,
        "GET / HTTP/1.1\r\nHost: #{site}\r\nUser-Agent: vintage_net/1.1\r\nAccept: */*\r\n\r\n"
      )

    {:ok, _} = :gen_tcp.recv(socket, 0, 500)

    # Now check the whether the connection is found again and triggers the internet to be detected
    {status, cache} =
      Inspector.check_ports({:unknown, %{}}, [socket], [{src_ip, {255, 255, 255, 0}}], cache)

    assert status == :internet
    assert Map.has_key?(cache, socket)

    # Close the socket
    :ok = :gen_tcp.close(socket)

    # Now check that the socket is not found and has been removed from the cache
    # Now check the whether the connection is found again and triggers the internet to be detected
    {status, cache} =
      Inspector.check_ports({:unknown, %{}}, [], [{src_ip, {255, 255, 255, 0}}], cache)

    assert status == :unknown
    refute Map.has_key?(cache, socket)
  end

  if Code.ensure_loaded(:gen_tcp_socket) == {:module, :gen_tcp_socket} do
    test "finds connections using socket API sockets" do
      site = "whenwhere.nerves-project.org"

      # Run a super slow HTTP request to test
      {:ok, tcp_socket} =
        :gen_tcp_socket.connect(to_charlist(site), 80, [:binary, {:active, false}], 1000)

      {:ok, {src_ip, _src_port}} = :gen_tcp_socket.sockname(tcp_socket)

      # Hack to get extract the :socket from the :gen_tcp_socket.
      {_, _, {_, socket}} = tcp_socket

      # Simulate a first call. The status should be unknown, but the socket should be
      # in the cache.
      {status, cache} =
        Inspector.check_sockets({:unknown, %{}}, [socket], [{src_ip, {255, 255, 255, 0}}], %{})

      assert status == :unknown
      assert Map.has_key?(cache, socket)

      # Make traffic happen on the socket
      :ok =
        :gen_tcp_socket.send(
          tcp_socket,
          "GET / HTTP/1.1\r\nHost: #{site}\r\nAccept: text/html\r\n\r\n"
        )

      _ = :gen_tcp_socket.recv(tcp_socket, 1000, 500)

      # Now check the whether the connection is found again and triggers the internet to be detected
      {status, cache} =
        Inspector.check_sockets({:unknown, %{}}, [socket], [{src_ip, {255, 255, 255, 0}}], cache)

      assert status == :internet
      assert Map.has_key?(cache, socket)

      # Close the socket
      :ok = :gen_tcp_socket.close(tcp_socket)

      # Now check that the socket is not found and has been removed from the cache
      # Now check the whether the connection is found again and triggers the internet to be detected
      {status, cache} =
        Inspector.check_sockets({:unknown, %{}}, [], [{src_ip, {255, 255, 255, 0}}], cache)

      assert status == :unknown
      refute Map.has_key?(cache, socket)
    end
  end

  test "checking the internet of a bogus network interface fails nicely" do
    assert Inspector.check_internet("bogus0", %{}) == {:no_internet, %{}}
  end
end
