defmodule ToElixirTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  test "can send message from C" do
    assert capture_log(fn ->
             to_elixir = Application.app_dir(:vintage_net, ["priv", "to_elixir"])
             System.cmd(to_elixir, ["hello"])
           end) =~ "[debug] Got a generic message: hello"
  end

  test "udhcpc handler notifies Elixir" do
    assert capture_log(fn ->
             udhcpc_handler = Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])

             System.cmd(udhcpc_handler, ["command"],
               env: [
                 {"interface", "interface"},
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
             "[debug] Got a report from udhcpc: %{broadcast: \"broadcast\", command: \"command\", dns: \"dns\", domain: \"domain\", interface: \"interface\", ip: \"ip\", message: \"message\", router: \"router\", subnet: \"subnet\"}"
  end

  test "udhcpc handler handles unset fields" do
    assert capture_log(fn ->
             udhcpc_handler = Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])

             System.cmd(udhcpc_handler, ["command"],
               env: [
                 {"interface", "interface"},
                 {"broadcast", "broadcast"},
                 {"subnet", "subnet"},
                 {"router", "router"},
                 {"domain", "domain"},
                 {"dns", "dns"}
               ]
             )
             Process.sleep(250)
           end) =~
             "[debug] Got a report from udhcpc: %{broadcast: \"broadcast\", command: \"command\", dns: \"dns\", domain: \"domain\", interface: \"interface\", ip: \"\", message: \"\", router: \"router\", subnet: \"subnet\"}"
  end
end
