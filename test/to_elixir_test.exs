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
    assert capture_log(fn ->
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
           end) =~
             "[debug] udhcpc.deconfig(eth0): %{broadcast: \"192.168.9.255\", command: :deconfig, dns: [\"192.168.9.1\"], domain: \"example.net\", interface: \"eth0\", ip: \"192.168.9.131\", lease: \"86400\", mask: \"24\", opt53: \"05\", opt58: \"0000a8c0\", opt59: \"00012750\", router: [\"192.168.9.1\"], serverid: \"192.168.9.1\", siaddr: \"192.168.9.1\", subnet: \"255.255.255.0\"}"
  end

  test "udhcpc handler ignores uppercase fields" do
    assert capture_log(fn ->
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
           end) =~
             "[debug] udhcpc.deconfig(eth0): %{broadcast: \"broadcast\", command: :deconfig, domain: \"domain\", interface: \"eth0\", router: [\"router\"], subnet: \"subnet\"}"
  end

  test "udhcpc handler handles multiple dns" do
    assert capture_log(fn ->
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
           end) =~
             "[debug] udhcpc.deconfig(eth0): %{broadcast: \"broadcast\", command: :deconfig, dns: [\"1.1.1.1\", \"2.2.2.2\", \"3.3.3.3\", \"4.4.4.4\"], domain: \"domain\", interface: \"eth0\", ip: \"ip\", message: \"message\", subnet: \"subnet\"}"
  end
end
