defmodule VintageNetTest do
  use VintageNetTest.Case
  doctest VintageNet

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  setup do
    # Capture Application exited logs
    capture_log(fn ->
      Application.stop(:vintage_net)
      Application.start(:vintage_net)
    end)

    # Remove persisted files if anything hung around
    on_exit(fn ->
      File.rm(Path.join(Application.get_env(:vintage_net, :persistence_dir), "eth0"))
    end)

    :ok
  end

  test "program paths resolve" do
    # For testing, the ip program is overridden to use "false". Check that it
    # was resolved.
    false_path = Application.get_env(:vintage_net, :bin_ip)
    assert String.starts_with?(false_path, "/")
    assert File.exists?(false_path)

    # Busybox is included as an optional dependency and it should always install udhcpc
    assert Application.get_env(:vintage_net, :bin_udhcpd) =~ ~r"busybox.*priv.*/sbin/udhcpd"
  end

  test "configure fails on a missing type field" do
    assert {:error,
            "Missing :type field.\n\nThis should be set to a network technology. These are provided in other libraries.\nSee the `vintage_net` docs and cookbook for examples.\n"} ==
             VintageNet.configure("eth0", %{})
  end

  test "configure fails if technology isn't available" do
    assert {:error,
            "Invalid technology VintageNetWifi.\n\nCheck the spelling and that you have the dependency that provides it in your mix.exs.\nSee the `vintage_net` docs for examples.\n"} ==
             VintageNet.configure("eth0", %{type: VintageNetWifi})
  end

  @tag :requires_interfaces_monitor
  test "interfaces exist" do
    # On CircleCI, sometimes the interfaces monitor process is slow to start. This is ok.
    Process.sleep(500)

    interfaces = VintageNet.all_interfaces()
    assert interfaces != []

    # The loopback interface always exists, so check for it
    assert Enum.any?(interfaces, &String.starts_with?(&1, "lo"))
  end

  test "no interfaces are configured when testing" do
    assert [] == VintageNet.configured_interfaces()
  end

  test "info works with nothing configured" do
    output = capture_io(&VintageNet.info/0)

    assert output =~ "All interfaces"
    assert output =~ "Available interfaces"
    assert output =~ "No configured interfaces"
  end

  test "info works with a configured interface" do
    :ok = VintageNet.configure("eth0", %{type: VintageNet.Technology.Ethernet})

    # configure/2 is asynchronous, so wait for the interface to appear.
    Process.sleep(100)
    assert ["eth0"] == VintageNet.configured_interfaces()

    output = capture_io(&VintageNet.info/0)

    assert output =~ "All interfaces"
    assert output =~ "Available interfaces"
    assert output =~ "Interface eth0"
    assert output =~ "Type: VintageNet.Technology.Ethernet"
  end

  test "configure returns error on bad configurations" do
    assert match?({:error, _}, VintageNet.configure("eth0", %{this_totally_should_not_work: 1}))
  end

  test "configure persists by default" do
    path = Path.join(Application.get_env(:vintage_net, :persistence_dir), "eth0")

    :ok = VintageNet.configure("eth0", %{type: VintageNet.Technology.Ethernet})

    assert File.exists?(path)
  end

  test "configure does not persist on bad configurations" do
    path = Path.join(Application.get_env(:vintage_net, :persistence_dir), "eth0")

    {:error, _} = VintageNet.configure("eth0", %{this_totally_should_not_work: 1})

    refute File.exists?(path)
  end

  test "can turn off configuration persistence" do
    path = Path.join(Application.get_env(:vintage_net, :persistence_dir), "eth0")

    :ok = VintageNet.configure("eth0", %{type: VintageNet.Technology.Ethernet}, persist: false)

    refute File.exists?(path)
  end

  test "configuration_valid? works" do
    assert VintageNet.configuration_valid?("eth0", %{type: VintageNet.Technology.Ethernet})
    refute VintageNet.configuration_valid?("eth0", %{this_totally_should_not_work: 1})
  end

  # Check that get, get_by_prefix, and match are available in the public
  # interface. Better tests should be else.
  test "get" do
    # These properties should always exist
    assert [] == VintageNet.get(["available_interfaces"])
    assert :disconnected == VintageNet.get(["connection"])
  end

  test "get_by_prefix" do
    results = VintageNet.get_by_prefix([])

    # There may or may not be "interfaces", so don't check for those.
    assert {["available_interfaces"], []} in results
    assert {["connection"], :disconnected} in results
  end

  test "match" do
    assert [{["available_interfaces"], []}] ==
             VintageNet.match(["available_interfaces"])

    assert [{["available_interfaces"], []}, {["connection"], :disconnected}] ==
             VintageNet.match([:_])
  end

  test "verify system works", context do
    # create files here at some tmp place
    in_tmp(context.test, fn ->
      opts = Application.get_all_env(:vintage_net) |> prefix_paths(File.cwd!())

      File.mkdir!("sbin")
      File.touch!("sbin/ifup")
      File.touch!("sbin/ifdown")
      File.touch!("sbin/ip")
      assert :ok == VintageNet.verify_system(opts)
    end)
  end

  test "max interface count works" do
    assert 8 == VintageNet.max_interface_count()
  end

  defp prefix_paths(opts, prefix) do
    Enum.map(opts, fn kv -> prefix_path(kv, prefix) end)
  end

  defp prefix_path({key, path}, prefix) do
    key_str = to_string(key)

    if String.starts_with?(key_str, "bin_") do
      {key, prefix <> path}
    else
      {key, path}
    end
  end
end
