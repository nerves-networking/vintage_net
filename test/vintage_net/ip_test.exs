defmodule VintageNet.IPTest do
  use ExUnit.Case
  doctest VintageNet.IP
  alias VintageNet.IP

  test "all IPv4 prefix lengths convert" do
    for prefix_length <- 0..32 do
      subnet_mask = IP.prefix_length_to_subnet_mask(:inet, prefix_length)

      assert {:ok, prefix_length} = IP.subnet_mask_to_prefix_length(subnet_mask)
    end
  end

  test "ip_to_tuple catches bad IP addresses" do
    assert {:error, "Invalid IP address: hostname.com"} == IP.ip_to_tuple("hostname.com")
    assert {:error, "Invalid IP address: 1.2.3.4.5"} == IP.ip_to_tuple("1.2.3.4.5")
    assert {:error, "Invalid IP address: {512, 0, 0, 1}"} == IP.ip_to_tuple({512, 0, 0, 1})

    assert {:error, "Invalid IP address: {-1, 0, 1, 2, 3, 4, 5, 6}"} ==
             IP.ip_to_tuple({-1, 0, 1, 2, 3, 4, 5, 6})
  end

  test "ip_to_tuple! raises or not" do
    assert {1, 2, 3, 4} == IP.ip_to_tuple!("1.2.3.4")

    assert_raise ArgumentError, fn ->
      IP.ip_to_tuple!("1.2.3.4.5")
    end
  end

  test "ip_to_string doesn't let bad IP addresses conversion propagate" do
    # This is more of an internal API, so the error doesn't need to be pretty,
    # but it's important that it crashes if :inet.ntoa/1 returns an error
    # tuple.
    assert_raise FunctionClauseError, fn ->
      IP.ip_to_string({0, 1, 2, 3, 4})
    end
  end
end
