defmodule VintageNet.WiFi.WPASupplicantLLTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias VintageNet.WiFi.WPASupplicantLL
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

  test "receives notifications", context do
    ll = start_supervised!({WPASupplicantLL, context.socket_path})
    :ok = WPASupplicantLL.subscribe(ll, self())

    MockWPASupplicant.send_message(context.mock, "<1>Hello")
    MockWPASupplicant.send_message(context.mock, "<2>Goodbye")

    assert_receive {VintageNet.WiFi.WPASupplicantLL, 1, "Hello"}
    assert_receive {VintageNet.WiFi.WPASupplicantLL, 2, "Goodbye"}
  end

  test "responds to requests", context do
    ll = start_supervised!({WPASupplicantLL, context.socket_path})
    :ok = WPASupplicantLL.subscribe(ll, self())

    MockWPASupplicant.set_responses(context.mock, %{"SCAN" => "OK"})

    assert {:ok, "OK"} = WPASupplicantLL.control_request(ll, "SCAN")
  end

  test "ignores unexpected responses", context do
    # capture_log hides the "log message from WPASupplicantLL when it sees an unexpected message"
    capture_log(fn ->
      ll = start_supervised!({WPASupplicantLL, context.socket_path})
      :ok = WPASupplicantLL.subscribe(ll, self())

      MockWPASupplicant.send_message(context.mock, "Bad response")

      # Wait a bit here and simultaneously make sure we don't get a notification
      refute_receive {VintageNet.WiFi.WPASupplicantLL, _priority, _message}

      # If WPASupplicantLL crashes, this will fail. Remove capture_log and look at the log messages.
      assert Process.alive?(ll)
    end)
  end

  test "handles notifications while waiting for a response", context do
    ll = start_supervised!({WPASupplicantLL, context.socket_path})
    :ok = WPASupplicantLL.subscribe(ll, self())

    MockWPASupplicant.set_responses(context.mock, %{"SCAN" => ["<1>Notification", "OK"]})

    assert {:ok, "OK"} = WPASupplicantLL.control_request(ll, "SCAN")
    assert_receive {VintageNet.WiFi.WPASupplicantLL, 1, "Notification"}
    assert MockWPASupplicant.get_requests(context.mock) == ["SCAN"]
  end

  test "multiple requests outstanding", context do
    ll = start_supervised!({WPASupplicantLL, context.socket_path})
    :ok = WPASupplicantLL.subscribe(ll, self())

    # Set up the responses so that REQUEST1 has to wait for REQUEST2
    # to be sent before it gets a response
    MockWPASupplicant.set_responses(context.mock, %{
      "REQUEST1" => [],
      "REQUEST2" => ["OK1", "OK2"]
    })

    spawn(fn ->
      assert {:ok, "OK1"} = WPASupplicantLL.control_request(ll, "REQUEST1")
    end)

    # Make sure that REQUEST1 has time to be sent
    Process.sleep(100)

    assert {:ok, "OK2"} = WPASupplicantLL.control_request(ll, "REQUEST2")
  end
end
