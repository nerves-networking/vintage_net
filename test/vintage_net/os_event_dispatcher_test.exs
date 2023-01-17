defmodule VintageNet.OSEventDispatcherTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias VintageNet.OSEventDispatcher
  alias VintageNetTest.{CapturingUdhcpcHandler, CapturingUdhcpdHandler}

  test "os event dispatcher writes raw config to property table" do
    info = %{
      "dns" => "192.168.1.149 1.1.1.1 9.9.9.9",
      "domain" => "localdomain",
      "interface" => "eth0",
      "ip" => "192.168.1.245",
      "lease" => "86400",
      "mask" => "24",
      "ntpsrv" => "192.168.1.149",
      "opt53" => "05",
      "router" => "192.168.1.1",
      "serverid" => "192.168.1.1",
      "subnet" => "255.255.255.0"
    }

    OSEventDispatcher.dispatch(["bound"], info)
    dhcp_options = PropertyTable.get(VintageNet, ["interface", "eth0", "dhcp_options"])
    assert dhcp_options == info

    OSEventDispatcher.dispatch(["deconfig"], info)
    dhcp_options = PropertyTable.get(VintageNet, ["interface", "eth0", "dhcp_options"])
    assert dhcp_options == nil
  end

  test "udhcpc handler notifies Elixir" do
    for op <- [:deconfig, :leasefail, :nak, :renew, :bound] do
      CapturingUdhcpcHandler.clear()

      OSEventDispatcher.dispatch([to_string(op)], %{
        "subnet" => "255.255.255.0",
        "router" => "192.168.9.1",
        "opt58" => "0000a8c0",
        "opt59" => "00012750",
        "domain" => "example.net",
        "interface" => "eth0",
        "siaddr" => "192.168.9.1",
        "dns" => "192.168.9.1",
        "serverid" => "192.168.9.1",
        "broadcast" => "192.168.9.255",
        "ip" => "192.168.9.131",
        "mask" => "24",
        "lease" => "86400",
        "opt53" => "05"
      })

      [{ifname, reported_op, options}] = CapturingUdhcpcHandler.get()
      assert reported_op == op
      assert ifname == "eth0"
      assert options["dns"] == ["192.168.9.1"]
      assert options["subnet"] == "255.255.255.0"
      assert options["router"] == ["192.168.9.1"]
      assert options["opt58"] == "0000a8c0"
      assert options["opt59"] == "00012750"
      assert options["domain"] == "example.net"
      assert options["siaddr"] == "192.168.9.1"
      assert options["serverid"] == "192.168.9.1"
      assert options["broadcast"] == "192.168.9.255"
      assert options["ip"] == "192.168.9.131"
      assert options["mask"] == "24"
      assert options["lease"] == "86400"
      assert options["opt53"] == "05"
    end
  end

  test "udhcpc handler handles multiple dns" do
    CapturingUdhcpcHandler.clear()

    OSEventDispatcher.dispatch(["bound"], %{
      "interface" => "eth0",
      "ip" => "ip",
      "broadcast" => "broadcast",
      "subnet" => "subnet",
      "domain" => "domain",
      "dns" => "1.1.1.1 2.2.2.2 3.3.3.3 4.4.4.4",
      "message" => "message"
    })

    [{ifname, reported_op, options}] = CapturingUdhcpcHandler.get()
    assert reported_op == :bound
    assert ifname == "eth0"
    assert options["ip"] == "ip"
    assert options["broadcast"] == "broadcast"
    assert options["subnet"] == "subnet"
    assert options["domain"] == "domain"
    assert options["dns"] == ["1.1.1.1", "2.2.2.2", "3.3.3.3", "4.4.4.4"]
    assert options["message"] == "message"
  end

  test "udhcpd handler notifies Elixir" do
    CapturingUdhcpdHandler.clear()

    OSEventDispatcher.dispatch(["/tmp/vintage_net/udhcpd.wlan0.leases"], %{})

    [{ifname, reported_op, lease_file}] = CapturingUdhcpdHandler.get()
    assert reported_op == :lease_update
    assert ifname == "wlan0"
    assert lease_file == "/tmp/vintage_net/udhcpd.wlan0.leases"
  end

  test "udhcpd handler with relative path notifies Elixir" do
    CapturingUdhcpdHandler.clear()

    OSEventDispatcher.dispatch(["udhcpd.wlan1.leases"], %{})

    [{ifname, reported_op, lease_file}] = CapturingUdhcpdHandler.get()
    assert reported_op == :lease_update
    assert ifname == "wlan1"
    assert lease_file == "udhcpd.wlan1.leases"
  end

  test "dispatcher warns on unknown messages" do
    CapturingUdhcpdHandler.clear()

    assert capture_log(fn ->
             OSEventDispatcher.dispatch(["hello"], %{})
           end) =~ "dropping unexpected notification"
  end

  test "dispatcher warns on unknown multi-arg messages" do
    CapturingUdhcpdHandler.clear()

    assert capture_log(fn ->
             OSEventDispatcher.dispatch(["hello", "world"], %{})
           end) =~ "dropping unexpected notification"
  end
end
