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
                 {"interface", "eth0"},
                 {"ip", "ip"},
                 {"broadcast", "broadcast"},
                 {"subnet", "subnet"},
                 {"router", "router"},
                 {"domain", "domain"},
                 {"dns", "dns"},
                 {"message", "message"}
               ]
             )

             Process.sleep(250)
           end) =~
             "[debug] udhcpc.deconfig(eth0): %{broadcast: \"broadcast\", command: :deconfig, dns: \"dns\", domain: \"domain\", interface: \"eth0\", ip: \"ip\", message: \"message\", router: \"router\", subnet: \"subnet\"}"
  end

  test "udhcpc handler handles unset fields" do
    assert capture_log(fn ->
             udhcpc_handler = Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])

             System.cmd(udhcpc_handler, ["deconfig"],
               env: [
                 {"interface", "eth0"},
                 {"broadcast", "broadcast"},
                 {"subnet", "subnet"},
                 {"router", "router"},
                 {"domain", "domain"},
                 {"dns", "dns"}
               ]
             )

             Process.sleep(250)
           end) =~
             "[debug] udhcpc.deconfig(eth0): %{broadcast: \"broadcast\", command: :deconfig, dns: \"dns\", domain: \"domain\", interface: \"eth0\", ip: \"\", message: \"\", router: \"router\", subnet: \"subnet\"}"
  end
end
