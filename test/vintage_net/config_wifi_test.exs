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
         ipv4: %{method: :dhcp}
       }}
    ]

    output = %{
      files: [
        {"/tmp/network_interfaces.wlan0", "iface wlan0 inet dhcp"},
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

    assert [{"wlan0", output}] == Config.make(input, default_opts())
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
         ipv4: %{method: :dhcp}
       }}
    ]

    output = %{
      files: [
        {"/tmp/network_interfaces.wlan0", "iface wlan0 inet dhcp"},
        {"/tmp/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/foo
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

    assert [{"wlan0", output}] == Config.make(input, default_opts())
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
         ipv4: %{method: :dhcp}
       }}
    ]

    output = %{
      files: [
        {"/tmp/network_interfaces.wlan0", "iface wlan0 inet dhcp"},
        {"/tmp/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/foo
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

    assert [{"wlan0", output}] == Config.make(input, default_opts())
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
        {"/tmp/network_interfaces.wlan0", "iface wlan0 inet dhcp"},
        {"/tmp/wpa_supplicant.conf.wlan0",
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

    assert [{"wlan0", output}] == Config.make(input, default_opts())
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
         ipv4: %{method: :dhcp}
       }}
    ]

    output = %{
      files: [
        {"/tmp/network_interfaces.wlan0", "iface wlan0 inet dhcp"},
        {"/tmp/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/foo
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

    assert [{"wlan0", output}] == Config.make(input, default_opts())
  end

  test "create a combo wired Ethernet and WPA2 WiFi configuration" do
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
       }}
    ]

    output_eth0 = %{
      files: [{"/tmp/network_interfaces.eth0", "iface eth0 inet dhcp"}],
      up_cmds: [{:run, "/sbin/ifup", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}],
      down_cmds: [{:run, "/sbin/ifdown", ["-i", "/tmp/network_interfaces.eth0", "eth0"]}]
    }

    output_wlan0 = %{
      files: [
        {"/tmp/network_interfaces.wlan0", "iface wlan0 inet dhcp"},
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

    assert [{"eth0", output_eth0}, {"wlan0", output_wlan0}] == Config.make(input, default_opts())
  end
end
