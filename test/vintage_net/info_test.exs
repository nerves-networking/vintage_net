# SPDX-FileCopyrightText: 2020 Frank Hunleth
# SPDX-FileCopyrightText: 2020 Jon Carstens
# SPDX-FileCopyrightText: 2022 Masatoshi Nishiguchi
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.InfoTest do
  use VintageNetTest.Case

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog
  alias VintageNet.Info

  doctest Info

  setup do
    capture_log(fn ->
      Application.stop(:vintage_net)
      Application.start(:vintage_net)
    end)

    on_exit(fn ->
      File.rm(Path.join(Application.get_env(:vintage_net, :persistence_dir), "eth0"))
      File.rm(Path.join(Application.get_env(:vintage_net, :persistence_dir), "wlan0"))
    end)

    :ok
  end

  test "summary sanitizes protected fields when verbose" do
    capture_log(fn ->
      :ok =
        VintageNet.configure("eth0", %{
          type: VintageNetTest.TestTechnology,
          arbitrary_config_name: %{psk: "psk1", password: "password1"},
          list_of_arbitrary_configuration: [
            %{psk: "psk2", password: "password2"},
            %{psk: "psk3", password: "password3"},
            %{preshared_key: "psk4"},
            %{sae_password: "sae1"}
          ],
          private_key: "priv_key"
        })

      Process.sleep(100)
      assert "eth0" in VintageNet.configured_interfaces()
    end)

    output = capture_io(fn -> Info.info("eth0", verbose: true) end)
    refute output =~ "psk1"
    refute output =~ "psk2"
    refute output =~ "psk3"
    refute output =~ "psk4"
    refute output =~ "password1"
    refute output =~ "password2"
    refute output =~ "password3"
    refute output =~ "sae1"
    refute output =~ "priv_key"
  end

  test "redact: false reveals secrets when verbose" do
    capture_log(fn ->
      :ok =
        VintageNet.configure("eth0", %{
          type: VintageNetTest.TestTechnology,
          arbitrary_config_name: %{psk: "psk1", password: "password1"},
          list_of_arbitrary_configuration: [
            %{psk: "psk2", password: "password2"},
            %{psk: "psk3", password: "password3"}
          ]
        })

      Process.sleep(100)
      assert ["eth0"] == VintageNet.configured_interfaces()
    end)

    output = capture_io(fn -> Info.info("eth0", redact: false, verbose: true) end)

    assert output =~ "psk1"
    assert output =~ "psk2"
    assert output =~ "psk3"
    assert output =~ "password1"
    assert output =~ "password2"
    assert output =~ "password3"
  end

  test "summary with nothing configured prints No interfaces" do
    output = capture_io(&Info.info/0)

    assert output =~ "host:"
    assert output =~ "Status: 0 of 0 online"
    assert output =~ "No interfaces"
  end

  test "info_as_ansidata returns ansidata" do
    output = Info.info_as_ansidata()
    output_str = output |> IO.ANSI.format(false) |> IO.chardata_to_string()

    assert output_str =~ "host:"
    assert output_str =~ "No interfaces"
  end

  test "summary shows a configured interface in the table" do
    capture_log(fn ->
      :ok = VintageNet.configure("eth0", %{type: VintageNetTest.TestTechnology})

      Process.sleep(100)
      assert ["eth0"] == VintageNet.configured_interfaces()
    end)

    output = capture_io(&Info.info/0)

    assert output =~ ~r/\bIF\b/
    assert output =~ ~r/\bCONN\b/
    assert output =~ ~r/\bTYPE\b/
    assert output =~ "eth0"
  end

  test "summary hides configuration by default" do
    capture_log(fn ->
      :ok =
        VintageNet.configure("eth0", %{
          type: VintageNetTest.TestTechnology,
          some_marker: "look_for_me"
        })

      Process.sleep(100)
      assert ["eth0"] == VintageNet.configured_interfaces()
    end)

    output = capture_io(&Info.info/0)

    refute output =~ "look_for_me"
    assert output =~ "verbose: true"
  end

  test "summary footer suggests detail and verbose options" do
    capture_log(fn ->
      :ok = VintageNet.configure("eth0", %{type: VintageNetTest.TestTechnology})

      Process.sleep(100)
      assert ["eth0"] == VintageNet.configured_interfaces()
    end)

    output = capture_io(&Info.info/0)

    assert output =~ "VintageNet.info(\"<ifname>\")"
    assert output =~ "verbose: true"
  end

  test "info(ifname) shows the detail view" do
    capture_log(fn ->
      :ok =
        VintageNet.configure("eth0", %{
          type: VintageNetTest.TestTechnology,
          some_marker: "look_for_me"
        })

      Process.sleep(100)
      assert ["eth0"] == VintageNet.configured_interfaces()
    end)

    output = capture_io(fn -> Info.info("eth0") end)

    assert output =~ "Interface eth0"
    refute output =~ "look_for_me"
  end

  test "info(ifname, verbose: true) shows the configuration" do
    capture_log(fn ->
      :ok =
        VintageNet.configure("eth0", %{
          type: VintageNetTest.TestTechnology,
          some_marker: "look_for_me"
        })

      Process.sleep(100)
      assert ["eth0"] == VintageNet.configured_interfaces()
    end)

    output = capture_io(fn -> Info.info("eth0", verbose: true) end)

    assert output =~ "Interface eth0"
    assert output =~ "Configuration:"
    assert output =~ "look_for_me"
  end

  test "info(ifname) for an unknown interface" do
    output = capture_io(fn -> Info.info("nope0") end)
    assert output =~ "nope0"
    assert output =~ "not configured"
  end

  test "AP configuration is shown in detail view with verbose" do
    ap_config = %{
      dhcpd: %{
        end: {192, 168, 0, 254},
        max_leases: 235,
        options: %{
          dns: [{192, 168, 0, 1}],
          domain: "mydomain.com",
          router: [{192, 168, 0, 1}],
          search: ["mydomain.com"],
          subnet: {255, 255, 255, 0}
        },
        start: {192, 168, 0, 20}
      },
      dnsd: %{records: [{"mydomain.com", {192, 168, 0, 1}}]},
      ipv4: %{address: {192, 168, 0, 1}, method: :static, prefix_length: 24},
      type: VintageNetTest.TestTechnology,
      vintage_net_wifi: %{
        networks: [%{key_mgmt: :wpa_psk, mode: :ap, ssid: "my-network", psk: "my-psk"}]
      }
    }

    capture_log(fn ->
      :ok = VintageNet.configure("wlan0", ap_config)

      Process.sleep(100)
      assert ["wlan0"] == VintageNet.configured_interfaces()
    end)

    output = capture_io(fn -> Info.info("wlan0", verbose: true) end)

    assert output =~ "Interface wlan0"
    assert output =~ "mode: :ap"
    assert output =~ "mydomain.com"
    assert output =~ "psk: \"....\""
  end

  test "friendly_time formatting" do
    ns = 1_000_000_000
    assert Info.friendly_time(123) |> to_string() == "123 ns"
    assert Info.friendly_time(123_456) |> to_string() == "123.5 μs"
    assert Info.friendly_time(123_456_789) |> to_string() == "123.5 ms"
    assert Info.friendly_time(12 * ns) |> to_string() == "12.0 s"
    assert Info.friendly_time(72 * ns) |> to_string() == "0:01:12"
    assert Info.friendly_time(60 * 60 * ns) |> to_string() == "1:00:00"
    assert Info.friendly_time(2 * 86400 * ns + 60 * ns) |> to_string() == "2 days, 0:01:00"
  end
end
