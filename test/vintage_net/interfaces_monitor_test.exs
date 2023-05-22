defmodule VintageNet.InterfacesMonitorTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias VintageNet.InterfacesMonitor

  doctest InterfacesMonitor

  setup do
    # Capture Application exited logs
    capture_log(fn ->
      Application.stop(:vintage_net)
      Application.start(:vintage_net)
    end)

    :ok
  end

  @tag :requires_interfaces_monitor
  test "interfaces known to :inet are in property table" do
    names = get_interfaces()

    # Avoid race on CircleCI
    Process.sleep(10)

    for name <- names do
      assert true == VintageNet.get(["interface", name, "present"])
    end
  end

  test "adding and removing links" do
    VintageNet.subscribe(["interface", "bogus0", "present"])

    send_report({:newlink, "bogus0", 56, %{}})
    assert_receive {VintageNet, ["interface", "bogus0", "present"], nil, true, %{}}

    send_report({:dellink, "bogus0", 56, %{}})
    assert_receive {VintageNet, ["interface", "bogus0", "present"], true, nil, %{}}
  end

  test "renaming links" do
    VintageNet.subscribe(["interface", "bogus0", "present"])
    VintageNet.subscribe(["interface", "bogus2", "present"])

    send_report({:newlink, "bogus0", 56, %{}})
    assert_receive {VintageNet, ["interface", "bogus0", "present"], nil, true, %{}}

    send_report({:newlink, "bogus2", 56, %{}})
    assert_receive {VintageNet, ["interface", "bogus0", "present"], true, nil, %{}}
    assert_receive {VintageNet, ["interface", "bogus2", "present"], nil, true, %{}}
  end

  test "link fields show up as properties" do
    # When adding support for fields, remember to add them to the docs
    fields = [{"present", true}, {"lower_up", true}, {"mac_address", "70:85:c2:8f:98:e1"}]

    for {field, _expected} <- fields do
      VintageNet.subscribe(["interface", "bogus0", field])
    end

    # The current report from C has the following fields, but not all are exposed to Elixir.
    send_report(
      {:newlink, "bogus0", 56,
       %{
         broadcast: true,
         lower_up: true,
         mac_address: "70:85:c2:8f:98:e1",
         mac_broadcast: "ff:ff:ff:ff:ff:ff",
         mtu: 1500,
         multicast: true,
         operstate: :down,
         running: false,
         stats: %{
           collisions: 0,
           multicast: 0,
           rx_bytes: 0,
           rx_dropped: 0,
           rx_errors: 0,
           rx_packets: 0,
           tx_bytes: 0,
           tx_dropped: 0,
           tx_errors: 0,
           tx_packets: 0
         },
         type: :ethernet,
         up: true
       }}
    )

    for {field, expected} <- fields do
      assert_receive {VintageNet, ["interface", "bogus0", ^field], nil, ^expected, %{}}
    end
  end

  test "ipv4 addresses get reported" do
    VintageNet.subscribe(["interface", "bogus0", "addresses"])

    send_report({:newlink, "bogus0", 56, %{}})

    send_report(
      {:newaddr, 56,
       %{
         address: {192, 168, 9, 5},
         family: :inet,
         label: "bogus0",
         local: {192, 168, 9, 5},
         permanent: false,
         prefixlen: 24,
         scope: :universe
       }}
    )

    expected_address_info = %{
      family: :inet,
      scope: :universe,
      address: {192, 168, 9, 5},
      netmask: {255, 255, 255, 0},
      prefix_length: 24
    }

    assert_receive {VintageNet, ["interface", "bogus0", "addresses"], _before,
                    [^expected_address_info], %{}}

    # Send a second IP address
    send_report(
      {:newaddr, 56,
       %{
         address: {192, 168, 10, 10},
         family: :inet,
         label: "bogus0",
         local: {192, 168, 10, 10},
         permanent: false,
         prefixlen: 24,
         scope: :universe
       }}
    )

    assert_receive {VintageNet, ["interface", "bogus0", "addresses"], _before,
                    [
                      %{
                        family: :inet,
                        scope: :universe,
                        address: {192, 168, 10, 10},
                        netmask: {255, 255, 255, 0},
                        prefix_length: 24
                      },
                      %{
                        family: :inet,
                        scope: :universe,
                        address: {192, 168, 9, 5},
                        netmask: {255, 255, 255, 0},
                        prefix_length: 24
                      }
                    ], %{}}

    # Remove an address
    send_report(
      {:deladdr, 56,
       %{
         address: {192, 168, 10, 10},
         family: :inet,
         label: "bogus0",
         local: {192, 168, 10, 10},
         permanent: false,
         prefixlen: 24,
         scope: :universe
       }}
    )

    expected_address_info = %{
      family: :inet,
      scope: :universe,
      address: {192, 168, 9, 5},
      netmask: {255, 255, 255, 0},
      prefix_length: 24
    }

    assert_receive {VintageNet, ["interface", "bogus0", "addresses"], _before,
                    [^expected_address_info], %{}}
  end

  test "ipv4 ppp address gets reported correctly" do
    VintageNet.subscribe(["interface", "bogus0", "addresses"])

    send_report({:newlink, "bogus0", 56, %{}})

    send_report(
      {:newaddr, 56,
       %{
         address: {10, 64, 64, 64},
         family: :inet,
         label: "bogus0",
         local: {10, 0, 95, 181},
         permanent: true,
         prefixlen: 32,
         scope: :universe
       }}
    )

    expected_address_info = %{
      family: :inet,
      scope: :universe,
      address: {10, 0, 95, 181},
      netmask: {255, 255, 255, 255},
      prefix_length: 32
    }

    assert_receive {VintageNet, ["interface", "bogus0", "addresses"], _before,
                    [^expected_address_info], %{}}
  end

  test "ipv6 addresses get reported" do
    VintageNet.subscribe(["interface", "bogus0", "addresses"])

    send_report({:newlink, "bogus0", 56, %{}})

    send_report(
      {:newaddr, 56,
       %{
         address: {65152, 0, 0, 0, 45461, 64234, 43649, 26057},
         family: :inet6,
         permanent: true,
         prefixlen: 64,
         scope: :link
       }}
    )

    expected_address_info = %{
      family: :inet6,
      scope: :link,
      address: {65152, 0, 0, 0, 45461, 64234, 43649, 26057},
      netmask: {65535, 65535, 65535, 65535, 0, 0, 0, 0},
      prefix_length: 64
    }

    assert_receive {VintageNet, ["interface", "bogus0", "addresses"], _before,
                    [^expected_address_info], %{}}
  end

  test "address report beats link report" do
    # Check that the address report isn't lost if it arrives before
    # the initial link report

    VintageNet.subscribe(["interface", "bogus0", "addresses"])

    send_report(
      {:newaddr, 56,
       %{
         address: {192, 168, 9, 5},
         family: :inet,
         label: "bogus0",
         local: {192, 168, 9, 5},
         permanent: false,
         prefixlen: 24,
         scope: :universe
       }}
    )

    assert VintageNet.get(["interface", "bogus0", "addresses"]) == nil

    send_report({:newlink, "bogus0", 56, %{}})

    assert_receive {VintageNet, ["interface", "bogus0", "addresses"], _before,
                    [
                      %{
                        family: :inet,
                        scope: :universe,
                        address: {192, 168, 9, 5},
                        netmask: {255, 255, 255, 0},
                        prefix_length: 24
                      }
                    ], %{}}
  end

  test "address delete beats link delete" do
    # Check that if address removals are ignored if the link isn't around

    before_delete = VintageNet.get_by_prefix(["interface"])

    send_report(
      {:deladdr, 56,
       %{
         address: {192, 168, 9, 5},
         family: :inet,
         label: "bogus0",
         local: {192, 168, 9, 5},
         permanent: false,
         prefixlen: 24,
         scope: :universe
       }}
    )

    after_delete = VintageNet.get_by_prefix(["interface"])

    assert before_delete == after_delete
  end

  test "force clearing ipv4 addresses" do
    VintageNet.subscribe(["interface", "bogus0", "addresses"])
    send_report({:newlink, "bogus0", 56, %{}})

    send_report(
      {:newaddr, 56,
       %{
         address: {192, 168, 9, 5},
         family: :inet,
         label: "bogus0",
         local: {192, 168, 9, 5},
         permanent: false,
         prefixlen: 24,
         scope: :universe
       }}
    )

    send_report(
      {:newaddr, 56,
       %{
         address: {192, 168, 10, 10},
         family: :inet,
         label: "bogus0",
         local: {192, 168, 10, 10},
         permanent: false,
         prefixlen: 24,
         scope: :universe
       }}
    )

    # Clear out the mailbox for the above two reports (they're tested above)
    assert_receive {VintageNet, ["interface", "bogus0", "addresses"], nil, _one_address, %{}}

    assert_receive {VintageNet, ["interface", "bogus0", "addresses"], _one_address,
                    _two_addresses, %{}}

    # The real test
    InterfacesMonitor.force_clear_ipv4_addresses("bogus0")

    assert_receive {VintageNet, ["interface", "bogus0", "addresses"], _two_addresses, [], %{}}

    # Nothing should happen this time
    InterfacesMonitor.force_clear_ipv4_addresses("bogus0")

    refute_receive {VintageNet, ["interface", "bogus0", "addresses"], _anything, _anything2, %{}}
  end

  defp get_interfaces() do
    {:ok, interface_infos} = :inet.getifaddrs()
    for {name, _info} <- interface_infos, do: to_string(name)
  end

  defp send_report(report) do
    # Simulate a report coming from C
    state = :sys.get_state(Process.whereis(VintageNet.InterfacesMonitor))
    encoded_report = :erlang.term_to_binary(report)
    send(VintageNet.InterfacesMonitor, {state.port, {:data, encoded_report}})
  end
end
