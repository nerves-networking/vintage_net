defmodule VintageNet.InfoTest do
  use VintageNetTest.Case
  alias VintageNet.Info

  doctest Info

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  setup do
    # Capture Application exited logs
    capture_log(fn ->
      Application.stop(:vintage_net)
      Application.start(:vintage_net)
    end)

    # Remove persisted files if anything hung around
    on_exit(fn ->
      File.rm(Path.join(Application.get_env(:vintage_net, :persistence_dir), "eth0"))
      File.rm(Path.join(Application.get_env(:vintage_net, :persistence_dir), "wlan0"))
    end)

    :ok
  end

  test "info sanitizes psk and password fields" do
    capture_log(fn ->
      :ok =
        VintageNet.configure("eth0", %{
          type: VintageNetTest.TestTechnology,
          arbitrary_config_name: %{
            psk: "psk1",
            password: "password1"
          },
          list_of_arbitrary_configuration: [
            %{psk: "psk2", password: "password2"},
            %{psk: "psk3", password: "password3"}
          ]
        })

      # configure/2 is asynchronous, so wait for the interface to appear.
      Process.sleep(100)
      assert ["eth0"] == VintageNet.configured_interfaces()
    end)

    output = capture_io(&Info.info/0)
    refute output =~ "psk1"
    refute output =~ "psk2"
    refute output =~ "psk3"
    refute output =~ "password1"
    refute output =~ "password2"
    refute output =~ "password3"
  end

  test "info allows for not redacting" do
    capture_log(fn ->
      :ok =
        VintageNet.configure("eth0", %{
          type: VintageNetTest.TestTechnology,
          arbitrary_config_name: %{
            psk: "psk1",
            password: "password1"
          },
          list_of_arbitrary_configuration: [
            %{psk: "psk2", password: "password2"},
            %{psk: "psk3", password: "password3"}
          ]
        })

      # configure/2 is asynchronous, so wait for the interface to appear.
      Process.sleep(100)
      assert ["eth0"] == VintageNet.configured_interfaces()
    end)

    output =
      capture_io(fn ->
        Info.info(redact: false)
      end)

    assert output =~ "psk1"
    assert output =~ "psk2"
    assert output =~ "psk3"
    assert output =~ "password1"
    assert output =~ "password2"
    assert output =~ "password3"
  end

  test "info works with nothing configured" do
    output = capture_io(&Info.info/0)

    assert output =~ "All interfaces"
    assert output =~ "Available interfaces"
    assert output =~ "No configured interfaces"
  end

  test "info works with a configured interface" do
    capture_log(fn ->
      :ok = VintageNet.configure("eth0", %{type: VintageNetTest.TestTechnology})

      # configure/2 is asynchronous, so wait for the interface to appear.
      Process.sleep(100)
      assert ["eth0"] == VintageNet.configured_interfaces()
    end)

    output = capture_io(&Info.info/0)

    assert output =~ "All interfaces"
    assert output =~ "Available interfaces"
    assert output =~ "Interface eth0"
    assert output =~ "Type: VintageNetTest.TestTechnology"
  end

  test "info works with ap configuration" do
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

      # configure/2 is asynchronous, so wait for the interface to appear.
      Process.sleep(100)
      assert ["wlan0"] == VintageNet.configured_interfaces()
    end)

    output = capture_io(&Info.info/0)

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
