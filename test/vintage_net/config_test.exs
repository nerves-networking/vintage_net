defmodule VintageNet.ConfigTest do
  use ExUnit.Case
  alias VintageNet.Config

  doctest Config

  test "create a wired ethernet configuration" do
    locations = %{
      network_interfaces: "/tmp/network_interfaces",
      ifup: "/sbin/ifup",
      ifdown: "/sbin/ifdown"
    }

    input = [%{ifname: "eth0", ipv4: %{method: :dhcp}, ipv6: %{method: :automatic}}]

    output = %{
      network_interfaces: "iface eth0 inet dhcp",
      up_cmds: ["/sbin/ifup -i /tmp/network_interfaces eth0"],
      down_cmds: ["/sbin/ifdown -i /tmp/network_interfaces eth0"]
    }

    assert output == Config.apply(input, locations: locations)
  end

  test "create a wireless ethernet configuration" do
    locations = %{
      network_interfaces: "/tmp/network_interfaces",
      wpa_supplicant_conf: "/tmp/wpa_supplicant.conf",
      wpa_supplicant_control: "/tmp/foo",
      ifup: "/sbin/ifup",
      ifdown: "/sbin/ifdown"
    }

    input = [
      %{
        ifname: "wlan0",
        wifi: %{
          ssid: "testme",
          psk: "1234567890123456789012345678901234567890123456789012345678901234",
          key_mgmt: :wpa_psk
        },
        ipv4: %{method: :dhcp},
        ipv6: %{method: :automatic}
      }
    ]

    output = %{
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

    assert output == Config.apply(input)
  end

  test "create an LTE configuration" do
    input = []

    output = %{
      network_interfaces: "",
      up_cmds: [
        "mknod /dev/ppp c 108 0",
        "pppd connect \"/usr/sbin/chat -v -f /path/to/provider_chat_script\" ttyUSB1 115200 usepeerdns blabla"
      ],
      down_cmds: ["killall -q pppd"]
    }

    output = :ok

    assert output == Config.apply(input)
  end
end
