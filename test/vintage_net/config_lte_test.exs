defmodule VintageNet.ConfigLTETest do
  use ExUnit.Case
  alias VintageNet.Config
  import VintageNetTest.Utils

  defp ppp_config() do
    %{
      type: :mobile,
      pppd: %{
        options: [:noipdefault, :usepeerdns, :defaultroute, :noauth, :persist],
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
    }
  end

  defp ppp_output() do
    %{
      files: [
        {"/tmp/chat_script",
         """
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
         """}
      ],
      up_cmds: [
        {:run, "/bin/mknod", ["/dev/ppp", "c", "108", "0"]},
        {:run, "/usr/sbin/pppd",
         [
           "connect",
           "/usr/sbin/chat -v -f /tmp/chat_script",
           "/dev/ttyUSB1",
           "115200",
           "noipdefault",
           "usepeerdns",
           "defaultroute",
           "noauth",
           "persist"
         ]}
      ],
      down_cmds: [{:run, "/usr/bin/killall", ["-q", "pppd"]}]
    }
  end

  test "create an LTE configuration" do
    input = [
      {"ppp0", ppp_config()}
    ]

    output = ppp_output()

    assert [{"ppp0", output}] == Config.make(input, default_opts())
  end

  test "create a combo wired Ethernet, WPA2 WiFi, LTE configuration" do
    input = [
      {"eth0", %{type: :ethernet, ipv4: %{method: :dhcp}}},
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
       }},
      {"ppp0", ppp_config()}
    ]

    output_eth0 = %{
      files: [{"/tmp/network_interfaces.eth0", dhcp_interface("eth0")}],
      up_cmds: [{:run, "/sbin/ifup", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}],
      down_cmds: [{:run, "/sbin/ifdown", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}]
    }

    output_wlan0 = %{
      files: [
        {"/tmp/network_interfaces.wlan0", dhcp_interface("wlan0")},
        {"/tmp/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/wpa_supplicant
         country=US
         network={
         ssid="testme"
         psk=1234567890123456789012345678901234567890123456789012345678901234
         key_mgmt=WPA-PSK


         }
         """}
      ],
      up_cmds: [
        {:run, "/usr/sbin/wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "/sbin/ifup", ["-i", "/tmp/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "/sbin/ifdown", ["-i", "/tmp/network_interfaces.wlan0", "wlan0"]},
        {:run, "/usr/bin/killall", ["-q", "wpa_supplicant"]}
      ]
    }

    assert [{"eth0", output_eth0}, {"wlan0", output_wlan0}, {"ppp0", ppp_output()}] ==
             Config.make(input, default_opts())
  end
end
