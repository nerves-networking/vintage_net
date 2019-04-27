defmodule VintageNet.ConfigAPTest do
  use ExUnit.Case

  # TBD

  test "create a wireless AP configuration" do
    input = %{
      type: :wifi_ap,
      wifi: %{
        regulatory_domain: "US",
        ssid: "my_accesspoint",
        mode: :ap,
        psk: "1234567890123456789012345678901234567890123456789012345678901234",
        key_mgmt: :wpa_psk
      },
      ipv4: %{
        method: :dhcpd,
        addresses: [
          %{address: "192.168.0.2", netmask: "255.255.255.0", gateway: "192.168.0.1"}
        ],
        dhcpd: %{lease_start: "192.168.0.10", lease_end: "192.168.0.100"}
      }
    }

    output = %{
      files: [
        {"/tmp/network_interfaces.wlan0",
         """
         pre-up /usr/sbin/wpa_supplicant -B -i wlan0 -c /tmp/wpa_supplicant.conf.wlan0 -dd
         post-down /usr/sbin/killall -q wpa_supplicant; /usr/sbin/killall -q udhcpcd
         """},
        {"/tmp/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/wpa_supplicant
         country=US

         network={
           ap_scan=2
           mode=2
           ssid="my_accesspoint"
           psk=1234567890123456789012345678901234567890123456789012345678901234
           key_mgmt=WPA-PSK
         }
         """},
        {"/tmp/udhcpd.conf",
         """
         start 192.168.0.10
         end	192.168.0.100
         interface	wlan0
         """}
      ],
      up_cmds: [{:run, "/sbin/ifup", ["-i", "/tmp/network_interfaces.wlan0", "wlan0"]}],
      down_cmds: [{:run, "/sbin/ifdown", ["-i", "/tmp/network_interfaces.wlan0", "wlan0"]}]
    }

    # TODO!!!!
    # assert output == WiFiAP.to_raw_config("wlan0", input, default_opts())
  end
end
