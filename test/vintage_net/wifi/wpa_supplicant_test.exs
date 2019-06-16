defmodule VintageNet.WiFi.WPASupplicantTest do
  use ExUnit.Case

  alias VintageNet.WiFi.WPASupplicant
  alias VintageNetTest.MockWPASupplicant

  setup do
    socket_path = "test_tmp/tmp_wpa_supplicant_socket"
    mock = start_supervised!({MockWPASupplicant, socket_path})

    on_exit(fn ->
      _ = File.rm(socket_path)
      _ = File.rm(socket_path <> ".ex")
    end)

    {:ok, socket_path: socket_path, mock: mock}
  end

  test "attaches to wpa_supplicant", context do
    MockWPASupplicant.set_responses(context.mock, %{"ATTACH" => ["OK\n"]})
    _ = start_supervised!({WPASupplicant, control_path: context.socket_path})

    Process.sleep(100)
    assert MockWPASupplicant.get_requests(context.mock) == ["ATTACH"]
  end

  test "pings wpa_supplicant", context do
    MockWPASupplicant.set_responses(context.mock, %{"ATTACH" => "OK\n", "PING" => "PONG\n"})

    _ =
      start_supervised!(
        {WPASupplicant, control_path: context.socket_path, keep_alive_interval: 10}
      )

    Process.sleep(100)
    requests = MockWPASupplicant.get_requests(context.mock)
    assert "ATTACH" in requests
    assert "PING" in requests
  end
end
