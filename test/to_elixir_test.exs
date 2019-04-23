defmodule ToElixirTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  test "can send message from C" do
    assert capture_log(fn ->
             to_elixir = Application.app_dir(:vintage_net, ["priv", "to_elixir"])
             System.cmd(to_elixir, ["hello"])
             Process.sleep(250)
           end) =~ "[debug] Got a generic message: hello"
  end

  test "udhcpc handler notifies Elixir" do
    log =
      capture_log(fn ->
        udhcpc_handler = Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])

        System.cmd(udhcpc_handler, ["deconfig"],
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

        Process.sleep(250)
      end)

    assert log =~ "broadcast: \"192.168.9.255\""
    assert log =~ "command: :deconfig"
    assert log =~ "dns: [\"192.168.9.1\"]"
    assert log =~ "domain: \"example.net\""
    assert log =~ "interface: \"eth0\""
    assert log =~ "ip: \"192.168.9.131\""
    assert log =~ "lease: \"86400\""
    assert log =~ "mask: \"24\""
    assert log =~ "opt53: \"05\""
    assert log =~ "opt58: \"0000a8c0\""
    assert log =~ "opt59: \"00012750\""
    assert log =~ "router: [\"192.168.9.1\"]"
    assert log =~ "serverid: \"192.168.9.1\""
    assert log =~ "siaddr: \"192.168.9.1\""
    assert log =~ "subnet: \"255.255.255.0\""
  end

  test "udhcpc handler ignores uppercase fields" do
    log =
      capture_log(fn ->
        udhcpc_handler = Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])

        System.cmd(udhcpc_handler, ["deconfig"],
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

        Process.sleep(250)
      end)

    assert log =~ "broadcast: \"broadcast\""
    assert log =~ "command: :deconfig"
    assert log =~ "domain: \"domain\""
    assert log =~ "interface: \"eth0\""
    assert log =~ "router: [\"router\"]"
    assert log =~ "subnet: \"subnet\""
  end

  test "udhcpc handler handles multiple dns" do
    log =
      capture_log(fn ->
        udhcpc_handler = Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])

        System.cmd(udhcpc_handler, ["deconfig"],
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
