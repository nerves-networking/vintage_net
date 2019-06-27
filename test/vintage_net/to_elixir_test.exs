defmodule VintageNet.ToElixirTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias VintageNetTest.CapturingUdhcpcHandler

  test "can send message from C" do
    assert capture_log(fn ->
             to_elixir = Application.app_dir(:vintage_net, ["priv", "to_elixir"])
             System.cmd(to_elixir, ["hello", "from", "a", "c", "program"])
             Process.sleep(100)
           end) =~ "[debug] Got a generic message: hello from a c program"
  end

  test "udhcpc handler notifies Elixir" do
    udhcpc_handler = Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])

    for op <- [:deconfig, :leasefail, :nak, :renew, :bound] do
      CapturingUdhcpcHandler.clear()

      {_, 0} =
        System.cmd(udhcpc_handler, [to_string(op)],
          env: [
            {"subnet", "255.255.255.0"},
            {"router", "192.168.9.1"},
            {"opt58", "0000a8c0"},
            {"opt59", "00012750"},
            {"domain", "example.net"},
            {"interface", "eth0"},
            {"siaddr", "192.168.9.1"},
            {"dns", "192.168.9.1"},
            {"serverid", "192.168.9.1"},
            {"broadcast", "192.168.9.255"},
            {"ip", "192.168.9.131"},
            {"mask", "24"},
            {"lease", "86400"},
            {"opt53", "05"}
          ]
        )

      Process.sleep(100)

      [{ifname, reported_op, options}] = CapturingUdhcpcHandler.get()
      assert reported_op == op
      assert ifname == "eth0"
      assert options[:dns] == ["192.168.9.1"]
      assert options[:subnet] == "255.255.255.0"
      assert options[:router] == ["192.168.9.1"]
      assert options[:opt58] == "0000a8c0"
      assert options[:opt59] == "00012750"
      assert options[:domain] == "example.net"
      assert options[:siaddr] == "192.168.9.1"
      assert options[:serverid] == "192.168.9.1"
      assert options[:broadcast] == "192.168.9.255"
      assert options[:ip] == "192.168.9.131"
      assert options[:mask] == "24"
      assert options[:lease] == "86400"
      assert options[:opt53] == "05"
    end
  end

  test "udhcpc handler ignores uppercase fields" do
    udhcpc_handler = Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])
    CapturingUdhcpcHandler.clear()

    {_, 0} =
      System.cmd(udhcpc_handler, ["leasefail"],
        env: [
          {"interface", "eth0"},
          {"broadcast", "broadcast"},
          {"subnet", "subnet"},
          {"router", "router"},
          {"domain", "domain"},
          {"PATH", "stuff"},
          {"EMU", "beam"}
        ]
      )

    Process.sleep(100)

    [{ifname, reported_op, options}] = CapturingUdhcpcHandler.get()
    assert reported_op == :leasefail
    assert ifname == "eth0"
    assert options[:broadcast] == "broadcast"
    assert options[:domain] == "domain"
    assert options[:router] == ["router"]
    assert options[:subnet] == "subnet"
    assert options[:PATH] == nil
    assert options[:EMU] == nil
  end

  test "udhcpc handler handles multiple dns" do
    udhcpc_handler = Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])
    CapturingUdhcpcHandler.clear()

    {_, 0} =
      System.cmd(udhcpc_handler, ["bound"],
        env: [
          {"interface", "eth0"},
          {"ip", "ip"},
          {"broadcast", "broadcast"},
          {"subnet", "subnet"},
          {"domain", "domain"},
          {"dns", "1.1.1.1 2.2.2.2 3.3.3.3 4.4.4.4"},
          {"message", "message"}
        ]
      )

    Process.sleep(100)

    [{ifname, reported_op, options}] = CapturingUdhcpcHandler.get()
    assert reported_op == :bound
    assert ifname == "eth0"
    assert options[:ip] == "ip"
    assert options[:broadcast] == "broadcast"
    assert options[:subnet] == "subnet"
    assert options[:domain] == "domain"
    assert options[:dns] == ["1.1.1.1", "2.2.2.2", "3.3.3.3", "4.4.4.4"]
    assert options[:message] == "message"
  end

        Process.sleep(250)
      end)

    assert log =~ "broadcast: \"broadcast\""
    assert log =~ "command: :deconfig"
    assert log =~ "dns: [\"1.1.1.1\", \"2.2.2.2\", \"3.3.3.3\", \"4.4.4.4\"]"
    assert log =~ "domain: \"domain\""
    assert log =~ "interface: \"eth0\""
    assert log =~ "ip: \"ip\""
    assert log =~ "message: \"message\""
    assert log =~ "subnet: \"subnet\""
  end
end
