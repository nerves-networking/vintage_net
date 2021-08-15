defmodule VintageNet.Connectivity.InspectorTest do
  use ExUnit.Case

  alias VintageNet.Connectivity.Inspector
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

  test "finds connections" do
    # Run a super slow HTTP request to test
    {:ok, socket} = :gen_tcp.connect('neverssl.com', 80, [:binary, {:active, false}])
    {:ok, {src_ip, _src_port}} = :inet.sockname(socket)

    # Simulate a first call. The status should be unknown, but the socket should be
    # in the cache.
    {status, cache} =
      Inspector.check_sockets([socket], [{src_ip, {255, 255, 255, 0}}], %{}, {:unknown, %{}})

    assert status == :unknown
    assert Map.has_key?(cache, socket)

    # Make traffic happen on the socket
    :ok =
      :gen_tcp.send(socket, "GET / HTTP/1.1\r\nHost: neverssl.com\r\nAccept: text/html\r\n\r\n")

    _ = :gen_tcp.recv(socket, 1000, 500)

    # Now check the whether the connection is found again and triggers the internet to be detected
    {status, cache} =
      Inspector.check_sockets([socket], [{src_ip, {255, 255, 255, 0}}], cache, {:unknown, %{}})

    assert status == :available
    assert Map.has_key?(cache, socket)

    # Close the socket
    :ok = :gen_tcp.close(socket)

    # Now check that the socket is not found and has been removed from the cache
    # Now check the whether the connection is found again and triggers the internet to be detected
    {status, cache} =
      Inspector.check_sockets([], [{src_ip, {255, 255, 255, 0}}], cache, {:unknown, %{}})

    assert status == :unknown
    refute Map.has_key?(cache, socket)
  end

  test "checking the internet of a bogus network interface fails nicely" do
    assert Inspector.check_internet("bogus0", %{}) == {:unavailable, %{}}
  end
end
