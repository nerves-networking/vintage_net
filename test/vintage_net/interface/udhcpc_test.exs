defmodule VintageNet.Interface.UdhcpcTest do
  use VintageNetTest.Case
  alias VintageNet.Interface.Udhcpc

  test "ifconfig_args" do
    info = %{ip: {192, 168, 1, 2}, broadcast: {192, 168, 1, 255}, subnet: {255, 255, 255, 0}}
    expected = ["eth0", "192.168.1.2", "broadcast", "192.168.1.255", "netmask", "255.255.255.0"]

    assert expected == Udhcpc.ifconfig_args("eth0", info)
  end

  test "ifconfig_args no broadcast or netmask" do
    info = %{ip: {192, 168, 1, 2}}
    expected = ["eth0", "192.168.1.2"]

    assert expected == Udhcpc.ifconfig_args("eth0", info)
  end
end
