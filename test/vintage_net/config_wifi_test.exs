defmodule VintageNet.ConfigWiFiTest do
  use ExUnit.Case
  alias VintageNet.Config

  defp default_opts() do
    [
      network_interfaces: "/tmp/network_interfaces",
      tmpdir: "/tmp",
      wpa_supplicant_conf: "/tmp/wpa_supplicant.conf",
      wpa_supplicant_control: "/tmp/foo",
      ifup: "/sbin/ifup",
      ifdown: "/sbin/ifdown",
      chat_bin: "/usr/sbin/chat",
      pppd: "/usr/sbin/pppd",
      mknod: "/bin/mknod",
      killall: "/usr/bin/killall",
      wpa_supplicant: "/usr/sbin/wpa_supplicant"
    ]
  end

  test "create a WiFi configuration" do
    input = [
      {"wlan0",
       %{
         type: :wifi,
         wifi: %{
           regulatory_domain: "US",
           ssid: "testme",
           mode: :client,
           psk: "1234567890123456789012345678901234567890123456789012345678901234",
           key_mgmt: :wpa_psk
         },
         ipv4: %{method: :dhcp}
       }}
    ]

    output = %{
      files: [
        {"/tmp/network_interfaces.wlan0",
         """
         pre-up /usr/sbin/wpa_supplicant -B -i wlan0 -c /tmp/wpa_supplicant.conf.wlan0 -dd
         post-down /usr/bin/killall -q wpa_supplicant
         """},
        {"/tmp/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/foo
         country=US

         network={
           ssid="testme"
           psk=1234567890123456789012345678901234567890123456789012345678901234
           key_mgmt=WPA-PSK
         }
         """}
      ],
      up_cmds: ["/sbin/ifup -i /tmp/network_interfaces.wlan0 wlan0"],
      down_cmds: ["/sbin/ifdown -i /tmp/network_interfaces.wlan0 wlan0"]
    }

    assert output == Config.make(input, default_opts())
  end

  test "create a hidden WiFi configuration" do
    input = [
      {"wlan0",
       %{
         type: :wifi,
         wifi: %{
           regulatory_domain: "US",
           ssid: "testme",
           mode: :client,
           psk: "1234567890123456789012345678901234567890123456789012345678901234",
           key_mgmt: :wpa_psk,
           scan_ssid: 1
         },
         ipv4: %{method: :dhcp}
       }}
    ]

    output = %{
      files: [
        {"/tmp/network_interfaces",
         """
         pre-up wpa_supplicant -B -i wlan0 -c /tmp/wpa_supplicant.conf -dd
         post-down killall -q wpa_supplicant
         """},
        {"/tmp/wpa_supplicant.conf",
         """
         ctrl_interface=/tmp/foo
         country=US

         network={
           ssid="testme"
           psk=1234567890123456789012345678901234567890123456789012345678901234
           key_mgmt=WPA-PSK
           scan_ssid=1
         }
         """}
      ],
      up_cmds: ["/sbin/ifup -i /tmp/network_interfaces wlan0"],
      down_cmds: ["/sbin/ifdown -i /tmp/network_interfaces wlan0"]
    }

    assert output == Config.make(input, default_opts())
  end
end
