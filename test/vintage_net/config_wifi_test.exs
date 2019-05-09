defmodule VintageNet.ConfigWiFiTest do
  use ExUnit.Case
  alias VintageNet.Interface.RawConfig
  alias VintageNet.Technology.WiFi

  import VintageNetTest.Utils

  test "create a WPA2 WiFi configuration" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "testing",
        mode: :client,
        psk: "1234567890123456789012345678901234567890123456789012345678901234",
        key_mgmt: :wpa_psk
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: input,
      child_specs: [{VintageNet.Interface.ConnectivityChecker, "wlan0"}],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         psk=1234567890123456789012345678901234567890123456789012345678901234
         key_mgmt=WPA-PSK
         }
         """}
      ],
      up_cmds: [
        {:run, "/usr/sbin/wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "/sbin/ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "/sbin/ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "/usr/bin/killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create a WPA2 WiFi configuration with passphrase" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "testing",
        mode: :client,
        psk: "a_passphrase_and_not_a_psk",
        key_mgmt: :wpa_psk
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: input,
      child_specs: [{VintageNet.Interface.ConnectivityChecker, "wlan0"}],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         psk=1EE0A473A954F61007E526365D4FDC056FE2A102ED2CE77D64492A9495B83030
         key_mgmt=WPA-PSK
         }
         """}
      ],
      up_cmds: [
        {:run, "/usr/sbin/wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "/sbin/ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "/sbin/ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "/usr/bin/killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create a password-less WiFi configuration" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "testing",
        mode: :client,
        key_mgmt: :none
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: input,
      child_specs: [{VintageNet.Interface.ConnectivityChecker, "wlan0"}],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         key_mgmt=NONE
         }
         """}
      ],
      up_cmds: [
        {:run, "/usr/sbin/wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "/sbin/ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "/sbin/ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "/usr/bin/killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create a WEP WiFi configuration" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "testing",
        mode: :client,
        psk: "42FEEDDEAFBABEDEAFBEEFAA55",
        key_mgmt: :wep
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: input,
      child_specs: [{VintageNet.Interface.ConnectivityChecker, "wlan0"}],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         key_mgmt=NONE
         wep_tx_keyidx=0
         wep_key0=42FEEDDEAFBABEDEAFBEEFAA55
         }
         """}
      ],
      up_cmds: [
        {:run, "/usr/sbin/wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "/sbin/ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "/sbin/ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "/usr/bin/killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create a hidden WiFi configuration" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "testing",
        mode: :client,
        psk: "1234567890123456789012345678901234567890123456789012345678901234",
        key_mgmt: :wpa_psk,
        scan_ssid: 1
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: input,
      child_specs: [{VintageNet.Interface.ConnectivityChecker, "wlan0"}],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         psk=1234567890123456789012345678901234567890123456789012345678901234
         key_mgmt=WPA-PSK
         scan_ssid=1
         }
         """}
      ],
      up_cmds: [
        {:run, "/usr/sbin/wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "/sbin/ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "/sbin/ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "/usr/bin/killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create a basic EAP network" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "testing",
        mode: :client,
        key_mgmt: :wpa_eap,
        scan_ssid: 1,
        pairwise: "CCMP TKIP",
        group: "CCMP TKIP",
        eap: "PEAP",
        identity: "user1",
        password: "supersecret",
        phase1: "peapver=auto",
        phase2: "MSCHAPV2"
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: input,
      child_specs: [{VintageNet.Interface.ConnectivityChecker, "wlan0"}],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         key_mgmt=WPA-EAP
         scan_ssid=1
         pairwise=CCMP TKIP
         group=CCMP TKIP
         eap=PEAP
         identity=user1
         password=supersecret
         phase1=peapver=auto
         phase2=MSCHAPV2
         }
         """}
      ],
      up_cmds: [
        {:run, "/usr/sbin/wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "/sbin/ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "/sbin/ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "/usr/bin/killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create a multi-network WiFi configuration" do
    # All of the IPv4 settings need to be the same for this configuration. This is
    # probably "good enough". `nerves_network` does better, though.
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        mode: :client,
        networks: [
          %{
            ssid: "first_priority",
            psk: "1234567890123456789012345678901234567890123456789012345678901234",
            key_mgmt: :wpa_psk,
            priority: 100
          },
          %{
            ssid: "second_priority",
            psk: "1234567890123456789012345678901234567890123456789012345678901234",
            key_mgmt: :wpa_psk,
            priority: 1
          },
          %{
            ssid: "third_priority",
            psk: "1234567890123456789012345678901234567890123456789012345678901234",
            key_mgmt: :none,
            priority: 0
          }
        ]
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: input,
      child_specs: [{VintageNet.Interface.ConnectivityChecker, "wlan0"}],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="first_priority"
         psk=1234567890123456789012345678901234567890123456789012345678901234
         key_mgmt=WPA-PSK
         priority=100
         }
         network={
         ssid="second_priority"
         psk=1234567890123456789012345678901234567890123456789012345678901234
         key_mgmt=WPA-PSK
         priority=1
         }
         network={
         ssid="third_priority"
         psk=1234567890123456789012345678901234567890123456789012345678901234
         key_mgmt=NONE
         priority=0
         }
         """}
      ],
      up_cmds: [
        {:run, "/usr/sbin/wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "/sbin/ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "/sbin/ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "/usr/bin/killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end
end
