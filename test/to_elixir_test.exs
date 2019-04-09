defmodule ToElixirTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  test "can send message from C" do
    assert capture_log(fn ->
             to_elixir = Application.app_dir(:vintage_net, ["priv", "to_elixir"])
             System.cmd(to_elixir, [])
           end) =~ "[error] to_elixir: dropping unknown message 'hello'"
  end
end
