defmodule VintageNet.ConfigTest do
  use ExUnit.Case
  alias VintageNet.Config

  doctest Config

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
      ifup: "/sbin/ifup",
      ifdown: "/sbin/ifdown",
      killall: "/usr/bin/killall",
      ifup: "/sbin/ifup",
      ifdown: "/sbin/ifdown"
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
         }
         """}
      ],
      up_cmds: ["/sbin/ifup -i /tmp/network_interfaces wlan0"],
      down_cmds: ["/sbin/ifdown -i /tmp/network_interfaces wlan0"]
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

  test "create an LTE configuration" do
    input = [
      {"ppp0",
       %{
         type: :mobile,
         pppd: %{
           options: [:noipdefault, :usepeerdns, :defaultroute, :persist, :noauth],
           chat_script: """
           ABORT 'BUSY'
           ABORT 'NO CARRIER'
           ABORT 'NO DIALTONE'
           ABORT 'NO DIAL TONE'
           ABORT 'NO ANSWER'
           ABORT 'DELAYED'
           TIMEOUT 12
           REPORT CONNECT
           "" AT
           OK ATH
           OK ATZ
           OK ATQ0
           OK AT+CGDCONT=1,"IP","hologram"
           OK ATDT*99***1#
           CONNECT ''
           """,
           ttyname: "/dev/ttyUSB1",
           speed: 115_200
         }
       }}
    ]

    output = %{
      files: [],
      up_cmds: [
        "/bin/mknod /dev/ppp c 108 0",
        "/usr/sbin/pppd connect \"/usr/sbin/chat -v -f /tmp/chat_script\" /dev/ttyUSB1 115200 noipdefault usepeerdns defaultroute noauth persist noauth"
      ],
      down_cmds: ["/usr/bin/killall -q pppd"]
    }

    assert output == Config.make(input, default_opts())
  end
end
