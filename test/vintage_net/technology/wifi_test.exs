defmodule VintageNet.Technology.WiFiTest do
  use ExUnit.Case
  alias VintageNet.Interface.RawConfig
  alias VintageNet.Technology.WiFi

  import VintageNetTest.Utils

  defp normalize_config(config) do
    {:ok, normalized} = WiFi.normalize(config)
    normalized
  end

  test "normalization converts passphrases to psks" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "IEEE",
        psk: "password",
        key_mgmt: :wpa_psk
      }
    }

    normalized_input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "IEEE",
        psk: "F42C6FC52DF0EBEF9EBB4B90B38A5F902E83FE1B135A70E23AED762E9710A12E",
        key_mgmt: :wpa_psk
      }
    }

    assert {:ok, normalized_input} == WiFi.normalize(input)
  end

  test "create a WPA2 WiFi configuration" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "testing",
        psk: "1234567890123456789012345678901234567890123456789012345678901234",
        key_mgmt: :wpa_psk
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         key_mgmt=WPA-PSK
         psk=1234567890123456789012345678901234567890123456789012345678901234
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "Set regulatory_domain at runtime" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        regulatory_domain: "AU"
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=AU
         network={
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
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
        psk: "a_passphrase_and_not_a_psk",
        key_mgmt: :wpa_psk
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         key_mgmt=WPA-PSK
         psk=1EE0A473A954F61007E526365D4FDC056FE2A102ED2CE77D64492A9495B83030
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
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
        key_mgmt: :none
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
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
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
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
        bssid: "00:11:22:33:44:55",
        wep_key0: "42FEEDDEAFBABEDEAFBEEFAA55",
        wep_key1: "42FEEDDEAFBABEDEAFBEEFAA55",
        wep_key2: "ABEDEA42FFBEEFAA55EEDDEAFB",
        wep_key3: "EDEADEAFBABFBEEFAA5542FEED",
        key_mgmt: :none,
        wep_tx_keyidx: 0
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         bssid=00:11:22:33:44:55
         key_mgmt=NONE
         wep_key0=42FEEDDEAFBABEDEAFBEEFAA55
         wep_key1=42FEEDDEAFBABEDEAFBEEFAA55
         wep_key2=ABEDEA42FFBEEFAA55EEDDEAFB
         wep_key3=EDEADEAFBABFBEEFAA5542FEED
         wep_tx_keyidx=0
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
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
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="testing"
         key_mgmt=WPA-PSK
         scan_ssid=1
         psk=1234567890123456789012345678901234567890123456789012345678901234
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
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
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
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
         identity="user1"
         password="supersecret"
         pairwise=CCMP TKIP
         group=CCMP TKIP
         eap=PEAP
         phase1="peapver=auto"
         phase2="MSCHAPV2"
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "WPA-Personal(PSK) with TKIP and enforcement for frequent PTK rekeying" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "example",
        proto: "WPA",
        key_mgmt: :wpa_psk,
        scan_ssid: 1,
        pairwise: "TKIP",
        psk: "not so secure passphrase",
        wpa_ptk_rekey: 600
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example"
         key_mgmt=WPA-PSK
         scan_ssid=1
         psk=F7C00EB4F1A1BF28F0C6D18C689DB6634FC85C894286A11DE979F2BA1C022988
         wpa_ptk_rekey=600
         pairwise=TKIP
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "Only WPA-EAP is used. Both CCMP and TKIP is accepted" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "example",
        proto: "RSN",
        key_mgmt: :wpa_eap,
        pairwise: "CCMP TKIP",
        eap: "TLS",
        identity: "user@example.com",
        ca_cert: "/etc/cert/ca.pem",
        client_cert: "/etc/cert/user.pem",
        private_key: "/etc/cert/user.prv",
        private_key_passwd: "password",
        priority: 1
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example"
         key_mgmt=WPA-EAP
         priority=1
         identity="user@example.com"
         pairwise=CCMP TKIP
         eap=TLS
         ca_cert="/etc/cert/ca.pem"
         client_cert="/etc/cert/user.pem"
         private_key="/etc/cert/user.prv"
         private_key_passwd="password"
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "EAP-PEAP/MSCHAPv2 configuration for RADIUS servers that use the new peaplabel" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "example",
        key_mgmt: :wpa_eap,
        eap: "PEAP",
        identity: "user@example.com",
        password: "foobar",
        ca_cert: "/etc/cert/ca.pem",
        phase1: "peaplabel=1",
        phase2: "auth=MSCHAPV2",
        priority: 10
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example"
         key_mgmt=WPA-EAP
         priority=10
         identity="user@example.com"
         password="foobar"
         eap=PEAP
         phase1="peaplabel=1"
         phase2="auth=MSCHAPV2"
         ca_cert="/etc/cert/ca.pem"
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "EAP-TTLS/EAP-MD5-Challenge configuration with anonymous identity" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "example",
        key_mgmt: :wpa_eap,
        eap: "TTLS",
        identity: "user@example.com",
        anonymous_identity: "anonymous@example.com",
        password: "foobar",
        ca_cert: "/etc/cert/ca.pem",
        priority: 2
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example"
         key_mgmt=WPA-EAP
         priority=2
         identity="user@example.com"
         anonymous_identity="anonymous@example.com"
         password="foobar"
         eap=TTLS
         ca_cert="/etc/cert/ca.pem"
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "WPA-EAP, EAP-TTLS with different CA certificate used for outer and inner authentication" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "example",
        key_mgmt: :wpa_eap,
        eap: "TTLS",
        anonymous_identity: "anonymous@example.com",
        ca_cert: "/etc/cert/ca.pem",
        phase2: "autheap=TLS",
        ca_cert2: "/etc/cert/ca2.pem",
        client_cert2: "/etc/cer/user.pem",
        private_key2: "/etc/cer/user.prv",
        private_key2_passwd: "password",
        priority: 2
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example"
         key_mgmt=WPA-EAP
         priority=2
         anonymous_identity="anonymous@example.com"
         eap=TTLS
         phase2="autheap=TLS"
         ca_cert="/etc/cert/ca.pem"
         ca_cert2="/etc/cert/ca2.pem"
         client_cert2="/etc/cer/user.pem"
         private_key2="/etc/cer/user.prv"
         private_key2_passwd="password"
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "EAP-SIM with a GSM SIM or USIM" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "eap-sim-test",
        key_mgmt: :wpa_eap,
        eap: "SIM",
        pin: "1234",
        pcsc: ""
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="eap-sim-test"
         key_mgmt=WPA-EAP
         eap=SIM
         pin="1234"
         pcsc=""
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "EAP PSK" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "eap-psk-test",
        key_mgmt: :wpa_eap,
        eap: "PSK",
        anonymous_identity: "eap_psk_user",
        password: "06b4be19da289f475aa46a33cb793029",
        identity: "eap_psk_user@example.com"
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="eap-psk-test"
         key_mgmt=WPA-EAP
         identity="eap_psk_user@example.com"
         anonymous_identity="eap_psk_user"
         password="06b4be19da289f475aa46a33cb793029"
         eap=PSK
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "IEEE 802.1X/EAPOL with dynamically generated WEP keys" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "1x-test",
        key_mgmt: :IEEE8021X,
        eap: "TLS",
        identity: "user@example.com",
        ca_cert: "/etc/cert/ca.pem",
        client_cert: "/etc/cert/user.pem",
        private_key: "/etc/cert/user.prv",
        private_key_passwd: "password",
        eapol_flags: 3
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="1x-test"
         key_mgmt=IEEE8021X
         identity="user@example.com"
         eap=TLS
         eapol_flags=3
         ca_cert="/etc/cert/ca.pem"
         client_cert="/etc/cert/user.pem"
         private_key="/etc/cert/user.prv"
         private_key_passwd="password"
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "configuration blacklisting two APs" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "example",
        psk: "very secret passphrase",
        bssid_blacklist: "02:11:22:33:44:55 02:22:aa:44:55:66"
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example"
         bssid_blacklist=02:11:22:33:44:55 02:22:aa:44:55:66
         psk=3033345C1478F89E4BE9C4937401DEAFD58808CD3E63568DCBFBBD4A8D281175
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "configuration limiting AP selection to a specific set of APs" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "example",
        psk: "very secret passphrase",
        bssid_whitelist: "02:55:ae:bc:00:00/ff:ff:ff:ff:00:00 00:00:77:66:55:44/00:00:ff:ff:ff:ff"
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example"
         bssid_whitelist=02:55:ae:bc:00:00/ff:ff:ff:ff:00:00 00:00:77:66:55:44/00:00:ff:ff:ff:ff
         psk=3033345C1478F89E4BE9C4937401DEAFD58808CD3E63568DCBFBBD4A8D281175
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "host AP mode" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "example ap",
        psk: "very secret passphrase",
        key_mgmt: :wpa_psk,
        mode: :host
      },
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: true]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example ap"
         key_mgmt=WPA-PSK
         mode=2
         psk=94A7360596213CEB96007A25A63FCBCF4D540314CEB636353C62A86632A6BD6E
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: [
        "/tmp/vintage_net/wpa_supplicant/p2p-dev-wlan0",
        "/tmp/vintage_net/wpa_supplicant/wlan0"
      ]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create a multi-network WiFi configuration" do
    # All of the IPv4 settings need to be the same for this configuration. This is
    # probably "good enough". `nerves_network` does better, though.
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
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
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0", dhcp_interface("wlan0", "unit_test")},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="first_priority"
         key_mgmt=WPA-PSK
         priority=100
         psk=1234567890123456789012345678901234567890123456789012345678901234
         }
         network={
         ssid="second_priority"
         key_mgmt=WPA-PSK
         priority=1
         psk=1234567890123456789012345678901234567890123456789012345678901234
         }
         network={
         ssid="third_priority"
         key_mgmt=NONE
         priority=0
         psk=1234567890123456789012345678901234567890123456789012345678901234
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "creates a static ip config" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "example ap",
        psk: "very secret passphrase",
        key_mgmt: :wpa_psk
      },
      ipv4: %{
        method: :static,
        address: "192.168.1.2",
        netmask: "255.255.0.0",
        broadcast: "192.168.1.255",
        metric: "1000",
        gateway: "192.168.1.1",
        pointopoint: "192.168.1.100",
        hwaddress: "e8:6a:64:63:16:30",
        mtu: "1500",
        scope: "global"
      },
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: false]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0",
         """
         iface wlan0 inet static
           address 192.168.1.2
           broadcast 192.168.1.255
           gateway 192.168.1.1
           hwaddress e8:6a:64:63:16:30
           metric 1000
           mtu 1500
           netmask 255.255.0.0
           pointopoint 192.168.1.100
           scope global
           hostname unit_test
         """},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         network={
         ssid="example ap"
         key_mgmt=WPA-PSK
         psk=94A7360596213CEB96007A25A63FCBCF4D540314CEB636353C62A86632A6BD6E
         }
         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]}
      ],
      cleanup_files: ["/tmp/vintage_net/wpa_supplicant/wlan0"]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end

  test "create a dhcpd config" do
    input = %{
      type: VintageNet.Technology.WiFi,
      wifi: %{
        ssid: "example ap",
        key_mgmt: :none,
        scan_ssid: 1,
        ap_scan: 1,
        bgscan: :simple,
        mode: :host
      },
      ipv4: %{
        method: :static,
        address: "192.168.24.1",
        netmask: "255.255.255.0",
        gateway: "192.168.24.1"
      },
      dhcpd: %{
        start: "192.168.24.2",
        end: "192.168.24.100"
      },
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wlan0",
      type: VintageNet.Technology.WiFi,
      source_config: normalize_config(input),
      child_specs: [
        {VintageNet.Interface.ConnectivityChecker, "wlan0"},
        {VintageNet.WiFi.WPASupplicant,
         [ifname: "wlan0", control_path: "/tmp/vintage_net/wpa_supplicant", ap_mode: true]}
      ],
      files: [
        {"/tmp/vintage_net/network_interfaces.wlan0",
         """
         iface wlan0 inet static
           address 192.168.24.1
           gateway 192.168.24.1
           netmask 255.255.255.0
           hostname unit_test
         """},
        {"/tmp/vintage_net/wpa_supplicant.conf.wlan0",
         """
         ctrl_interface=/tmp/vintage_net/wpa_supplicant
         country=00
         bgscan="simple"
         ap_scan=1
         network={
         ssid="example ap"
         key_mgmt=NONE
         scan_ssid=1
         mode=2
         }
         """},
        {"/tmp/vintage_net/udhcpd.conf.wlan0",
         """
         interface wlan0
         pidfile /tmp/vintage_net/udhcpd.wlan0.pid
         lease_file /tmp/vintage_net/udhcpd.wlan0.leases
         notify_file #{Application.app_dir(:vintage_net, ["priv", "udhcpd_handler"])}

         end 192.168.24.100
         start 192.168.24.2

         """}
      ],
      up_cmd_millis: 60_000,
      up_cmds: [
        {:run_ignore_errors, "ifdown",
         ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run_ignore_errors, "killall", ["-q", "wpa_supplicant"]},
        {:run, "wpa_supplicant",
         ["-B", "-i", "wlan0", "-c", "/tmp/vintage_net/wpa_supplicant.conf.wlan0", "-dd"]},
        {:run, "ifup", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "udhcpd", ["/tmp/vintage_net/udhcpd.conf.wlan0"]}
      ],
      down_cmds: [
        {:run, "ifdown", ["-i", "/tmp/vintage_net/network_interfaces.wlan0", "wlan0"]},
        {:run, "killall", ["-q", "wpa_supplicant"]},
        {:run, "killall", ["-q", "udhcpd"]}
      ],
      cleanup_files: [
        "/tmp/vintage_net/wpa_supplicant/p2p-dev-wlan0",
        "/tmp/vintage_net/wpa_supplicant/wlan0"
      ]
    }

    assert {:ok, output} == WiFi.to_raw_config("wlan0", input, default_opts())
  end
end
