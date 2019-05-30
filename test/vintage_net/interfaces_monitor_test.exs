defmodule VintageNet.InterfacesMonitorTest do
  use ExUnit.Case

  alias VintageNet.InterfacesMonitor
  doctest InterfacesMonitor

  import ExUnit.CaptureLog

  setup do
    # Capture Application exited logs
    capture_log(fn ->
      Application.stop(:vintage_net)
      Application.start(:vintage_net)
    end)

    :ok
  end

  test "populates the property table" do
    names = get_interfaces()

    for name <- names do
      assert true == VintageNet.get(["interface", name, "present"])
    end
  end

  test "handles add and removes" do
    add_notification = {:added, "bogus0", 56}
    encoded_add = :erlang.term_to_binary(add_notification)

    VintageNet.subscribe(["interface", "bogus0", "present"])
    send(VintageNet.InterfacesMonitor, {:port, {:data, encoded_add}})

    assert_receive {VintageNet, ["interface", "bogus0", "present"], nil, true, %{}}

    removed_notification = {:removed, "bogus0", 56}
    encoded_removed = :erlang.term_to_binary(removed_notification)

    send(VintageNet.InterfacesMonitor, {:port, {:data, encoded_removed}})

    assert_receive {VintageNet, ["interface", "bogus0", "present"], true, nil, %{}}
  end

  test "rename" do
    add_notification = {:added, "bogus0", 56}
    encoded_add = :erlang.term_to_binary(add_notification)

    VintageNet.subscribe(["interface", "bogus0", "present"])
    VintageNet.subscribe(["interface", "bogus2", "present"])
    send(VintageNet.InterfacesMonitor, {:port, {:data, encoded_add}})

    assert_receive {VintageNet, ["interface", "bogus0", "present"], nil, true, %{}}

    renamed_notification = {:renamed, "bogus2", 56}
    encoded_renamed = :erlang.term_to_binary(renamed_notification)

    send(VintageNet.InterfacesMonitor, {:port, {:data, encoded_renamed}})

    assert_receive {VintageNet, ["interface", "bogus0", "present"], true, nil, %{}}
    assert_receive {VintageNet, ["interface", "bogus2", "present"], nil, true, %{}}
  end

  test "updates lower_up" do
    add_notification = {:added, "bogus0", 56}
    encoded_add = :erlang.term_to_binary(add_notification)

    VintageNet.subscribe(["interface", "bogus0", "present"])
    VintageNet.subscribe(["interface", "bogus0", "lower_up"])
    send(VintageNet.InterfacesMonitor, {:port, {:data, encoded_add}})

    assert_receive {VintageNet, ["interface", "bogus0", "present"], nil, true, %{}}

    report_notification = {:report, "bogus0", 56, %{lower_up: true}}
    encoded_report = :erlang.term_to_binary(report_notification)
    send(VintageNet.InterfacesMonitor, {:port, {:data, encoded_report}})
    assert_receive {VintageNet, ["interface", "bogus0", "lower_up"], nil, true, %{}}
  end

  defp get_interfaces() do
    {:ok, addrs} = :inet.getifaddrs()
    for {name, _info} <- addrs, do: to_string(name)
  end
end
