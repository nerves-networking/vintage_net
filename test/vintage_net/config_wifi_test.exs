defmodule VintageNet.ConfigWiFiTest do
  use ExUnit.Case
  alias VintageNet.Config
  alias VintageNet.Interface.RawConfig

  import VintageNetTest.Utils

  test "create a WPA2 WiFi configuration" do
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
         ipv4: %{method: :dhcp},
         hostname: "unittest"
       }}
    ]

    output = %RawConfig{
      ifname: "wlan0",
      files: [
        {"/tmp/network_interfaces.wlan0", dhcp_interface("wlan0", "unittest")},
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

    assert [output] == Config.make(input, default_opts())
  end

  test "create a password-less WiFi configuration" do
    input = [
      {"wlan0",
       %{
         type: :wifi,
         wifi: %{
           regulatory_domain: "US",
           ssid: "testme",
           mode: :client,
           key_mgmt: :none
         },
         ipv4: %{method: :dhcp},
         hostname: "unittest"
       }}
    ]

    output = %RawConfig{
      ifname: "wlan0",
      files: [
        {"/tmp/network_interfaces.wlan0", dhcp_interface("wlan0", "unittest")},
        {"/tmp/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/wpa_supplicant
         country=US
         network={
         ssid="testme"

         key_mgmt=NONE


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

    assert [output] == Config.make(input, default_opts())
  end

  test "create a WEP WiFi configuration" do
    input = [
      {"wlan0",
       %{
         type: :wifi,
         wifi: %{
           regulatory_domain: "US",
           ssid: "testme",
           mode: :client,
           psk: "42FEEDDEAFBABEDEAFBEEFAA55",
           key_mgmt: :wep
         },
         ipv4: %{method: :dhcp},
         hostname: "unittest"
       }}
    ]

    output = %RawConfig{
      ifname: "wlan0",
      files: [
        {"/tmp/network_interfaces.wlan0", dhcp_interface("wlan0", "unittest")},
        {"/tmp/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/wpa_supplicant
         country=US
         network={
         ssid="testme"
         key_mgmt=NONE
         wep_tx_keyidx=0
         wep_key0=42FEEDDEAFBABEDEAFBEEFAA55
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

    assert [output] == Config.make(input, default_opts())
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
         ipv4: %{method: :dhcp},
         hostname: "unittest"
       }}
    ]

    output = %RawConfig{
      ifname: "wlan0",
      files: [
        {"/tmp/network_interfaces.wlan0", dhcp_interface("wlan0", "unittest")},
        {"/tmp/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/wpa_supplicant
         country=US
         network={
         ssid="testme"
         psk=1234567890123456789012345678901234567890123456789012345678901234
         key_mgmt=WPA-PSK
         scan_ssid=1

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

    assert [output] == Config.make(input, default_opts())
  end

  test "create a multi-network WiFi configuration" do
    # All of the IPv4 settings need to be the same for this configuration. This is
    # probably "good enough". `nerves_network` does better, though.
    input = [
      {"wlan0",
       %{
         type: :wifi,
         wifi: %{
           regulatory_domain: "US",
           mode: :client,
           networks: [
             %{
               ssid: "firstpriority",
               psk: "1234567890123456789012345678901234567890123456789012345678901234",
               key_mgmt: :wpa_psk,
               priority: 100
             },
             %{
               ssid: "secondpriority",
               psk: "1234567890123456789012345678901234567890123456789012345678901234",
               key_mgmt: :wpa_psk,
               priority: 1
             },
             %{
               ssid: "thirdpriority",
               psk: "1234567890123456789012345678901234567890123456789012345678901234",
               key_mgmt: :none,
               priority: 0
             }
           ]
         },
         ipv4: %{method: :dhcp},
         hostname: "unittest"
       }}
    ]

    output = %RawConfig{
      ifname: "wlan0",
      files: [
        {"/tmp/network_interfaces.wlan0", dhcp_interface("wlan0", "unittest")},
        {"/tmp/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/wpa_supplicant
         country=US
         network={
         ssid="firstpriority"
         psk=1234567890123456789012345678901234567890123456789012345678901234
         key_mgmt=WPA-PSK

         priority=100
         }
         network={
         ssid="secondpriority"
         psk=1234567890123456789012345678901234567890123456789012345678901234
         key_mgmt=WPA-PSK

         priority=1
         }
         network={
         ssid="thirdpriority"
         psk=1234567890123456789012345678901234567890123456789012345678901234
         key_mgmt=NONE

         priority=0
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

    assert [output] == Config.make(input, default_opts())
  end

  test "create a combo wired Ethernet and WPA2 WiFi configuration" do
    input = [
      {"eth0", %{type: :ethernet, ipv4: %{method: :dhcp}, hostname: "unittest"}},
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
         ipv4: %{method: :dhcp},
         hostname: "unittest"
       }}
    ]

    output_eth0 = %RawConfig{
      ifname: "eth0",
      files: [{"/tmp/network_interfaces.eth0", dhcp_interface("eth0", "unittest")}],
      up_cmd_millis: 60_000,
      up_cmds: [{:run, "/sbin/ifup", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}],
      down_cmds: [{:run, "/sbin/ifdown", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}]
    }

    output_wlan0 = %RawConfig{
      ifname: "wlan0",
      files: [
        {"/tmp/network_interfaces.wlan0", dhcp_interface("wlan0", "unittest")},
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

    assert [output_eth0, output_wlan0] == Config.make(input, default_opts())
  end
end
