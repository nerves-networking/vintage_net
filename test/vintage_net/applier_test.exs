defmodule VintageNet.ApplierTest do
  use ExUnit.Case
  alias VintageNet.Applier

  doctest Applier

  test "applies wired ethernet configuration" do
    input = %{
      network_interfaces: "iface eth0 inet dhcp",
      up_cmds: ["ifup -i /tmp/network_interfaces eth0"],
      down_cmds: ["ifdown -i /tmp/network_interfaces eth0"]
    }

    output = :ok

    assert output == Applier.apply(input)
  end

  test "applies wireless ethernet configuration" do
    input = %{
      network_interfaces: """
      pre-up wpa_supplicant -B -i wlan0 -c /tmp/wpa_supplicant.conf -dd
      post-down killall -q wpa_supplicant
      """,
      wpa_supplicant_conf: """
      ctrl_interface=/tmp/foo

      network={
        ssid="testme"
        psk=1234567890123456789012345678901234567890123456789012345678901234
        key_mgmt=WPA-PSK
      }
      """,
      up_cmds: ["ifup -i /tmp/network_interfaces wlan0"],
      down_cmds: ["ifdown -i /tmp/network_interfaces wlan0"]
    }

    output = :ok

    assert output == Applier.apply(input)
  end

  test "applies LTE configuration" do
    input = %{
      network_interfaces: "",
      up_cmds: [
        "mknod /dev/ppp c 108 0",
        "pppd connect \"/usr/sbin/chat -v -f /path/to/provider_chat_script\" ttyUSB1 115200 usepeerdns blabla"
      ],
      down_cmds: ["killall -q pppd"]
    }

    output = :ok

    assert output == Applier.apply(input)
  end
end
