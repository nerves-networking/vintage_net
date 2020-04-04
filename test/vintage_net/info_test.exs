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

  test "IP address map parses getifaddrs" do
    ifaddrs = [
      {'lo',
       [
         flags: [:up, :loopback, :running],
         addr: {127, 0, 0, 1},
         netmask: {255, 0, 0, 0},
         addr: {0, 0, 0, 0, 0, 0, 0, 1},
         netmask: {65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535},
         hwaddr: [0, 0, 0, 0, 0, 0]
       ]},
      {'eth0',
       [
         flags: [:up, :broadcast, :running, :multicast],
         hwaddr: [152, 93, 173, 46, 158, 244]
       ]},
      {'wlan0',
       [
         flags: [:up, :broadcast, :running, :multicast],
         addr: {192, 168, 99, 37},
         netmask: {255, 255, 255, 0},
         broadaddr: {192, 168, 99, 255},
         addr: {65152, 0, 0, 0, 51770, 13823, 65226, 24336},
         netmask: {65535, 65535, 65535, 65535, 0, 0, 0, 0},
         hwaddr: [200, 58, 53, 202, 95, 16]
       ]},
      {'tap0',
       [
         flags: [:up, :broadcast, :running, :multicast],
         addr: {64768, 43690, 0, 0, 4144, 58623, 65276, 33158},
         netmask: {65535, 65535, 65535, 65535, 0, 0, 0, 0},
         addr: {64768, 43690, 0, 0, 0, 0, 0, 2},
         netmask: {65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535},
         addr: {65152, 0, 0, 0, 4144, 58623, 65276, 33158},
         netmask: {65535, 65535, 65535, 65535, 0, 0, 0, 0},
         hwaddr: [18, 48, 228, 252, 129, 134]
       ]}
    ]

    result = %{
      "eth0" => [],
      "lo" => ["::1/128", "127.0.0.1/8"],
      "tap0" => [
        "fe80::1030:e4ff:fefc:8186/64",
        "fd00:aaaa::2/128",
        "fd00:aaaa::1030:e4ff:fefc:8186/64"
      ],
      "wlan0" => ["fe80::ca3a:35ff:feca:5f10/64", "192.168.99.37/24"]
    }

    assert result == Info.ifaddrs_to_address_map(ifaddrs)
  end

  test "IP address map parses weird getifaddrs" do
    ifaddrs = [
      # Missing netmask
      {'lo',
       [
         addr: {127, 0, 0, 1},
         addr: {0, 0, 0, 0, 0, 0, 0, 1}
       ]},
      # netmask out of order
      {'wlan0',
       [
         addr: {192, 168, 99, 37},
         broadaddr: {192, 168, 99, 255},
         netmask: {255, 255, 255, 0},
         addr: {65152, 0, 0, 0, 51770, 13823, 65226, 24336},
         hwaddr: [200, 58, 53, 202, 95, 16],
         netmask: {65535, 65535, 65535, 65535, 0, 0, 0, 0}
       ]}
    ]

    result = %{
      "lo" => ["::1", "127.0.0.1"],
      "wlan0" => ["fe80::ca3a:35ff:feca:5f10", "192.168.99.37"]
    }

    assert result == Info.ifaddrs_to_address_map(ifaddrs)
  end
end
