# SPDX-FileCopyrightText: 2019 Frank Hunleth
# SPDX-FileCopyrightText: 2021 Matt Ludwigs
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetTest do
  use VintageNetTest.Case
  doctest VintageNet

  import ExUnit.CaptureLog

  setup do
    # Restart the VintageNet application, so all of the tests
    # can be in a pristine and consistent configuration.
    #
    # The following interfaces will exist:
    #
    # * "bogus0" - only in the application config
    # * "bogus1" - only in persistence store
    # * "bogus2" - in both the application config and persistence.
    #              The persistence config should override.
    capture_log(fn ->
      Application.stop(:vintage_net)

      # Just in case someone forgot to clean up...
      File.rm_rf!(Application.get_env(:vintage_net, :persistence_dir))

      Application.put_env(:vintage_net, :config, [
        {"bogus0",
         %{
           type: VintageNetTest.TestTechnology,
           bogus: 0
         }},
        {"bogus2",
         %{
           type: VintageNetTest.TestTechnology,
           bogus: -1
         }},
        {"invalid_config", :this, :should, :be, :ignored, :with, :a, :warning}
      ])

      VintageNet.Persistence.call(:save, [
        "bogus1",
        %{
          type: VintageNetTest.TestTechnology,
          bogus: 1
        }
      ])

      VintageNet.Persistence.call(:save, [
        "bogus2",
        %{
          type: VintageNetTest.TestTechnology,
          bogus: 2
        }
      ])

      Application.start(:vintage_net)

      # Loading of configurations is async and sometimes fails without short sleep
      Process.sleep(10)
    end)

    # Restore the configuration and persistance state to the original way
    on_exit(fn ->
      capture_log(fn ->
        Application.stop(:vintage_net)
        File.rm_rf!(Application.get_env(:vintage_net, :persistence_dir))
        Application.put_env(:vintage_net, :config, [])
        Application.start(:vintage_net)
      end)
    end)

    :ok
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

  test "only fake interfaces are configured when testing" do
    assert ["bogus0", "bogus1", "bogus2"] == VintageNet.configured_interfaces()
  end

  test "configure returns error on bad configurations" do
    assert match?({:error, _}, VintageNet.configure("eth0", %{this_totally_should_not_work: 1}))
  end

  test "calls normalize" do
    :ok = VintageNet.configure("eth0", %{type: VintageNetTest.TestTechnology})
    applied_config = VintageNet.get_configuration("eth0")

    # See TestTechnology's normalize/1 method
    assert Map.get(applied_config, :normalize_was_called)
  end

  test "configure persists by default" do
    path = Path.join(Application.get_env(:vintage_net, :persistence_dir), "eth0")

    :ok = VintageNet.configure("eth0", %{type: VintageNetTest.TestTechnology})

    assert File.exists?(path)
  end

  test "configure does not persist on bad configurations" do
    path = Path.join(Application.get_env(:vintage_net, :persistence_dir), "eth0")

    {:error, _} = VintageNet.configure("eth0", %{this_totally_should_not_work: 1})

    refute File.exists?(path)
  end

  test "can turn off configuration persistence" do
    path = Path.join(Application.get_env(:vintage_net, :persistence_dir), "eth0")

    :ok = VintageNet.configure("eth0", %{type: VintageNetTest.TestTechnology}, persist: false)

    assert VintageNet.get_configuration("eth0") == %{
             type: VintageNetTest.TestTechnology,
             normalize_was_called: true
           }

    refute File.exists?(path)
  end

  test "configuration_valid? works" do
    assert VintageNet.configuration_valid?("eth0", %{type: VintageNetTest.TestTechnology})
    refute VintageNet.configuration_valid?("eth0", %{this_totally_should_not_work: 1})
  end

  test "persisted configurations get restored" do
    assert VintageNet.get_configuration("bogus0") == %{
             type: VintageNetTest.TestTechnology,
             bogus: 0,
             normalize_was_called: true
           }

    assert VintageNet.get_configuration("bogus1") == %{
             type: VintageNetTest.TestTechnology,
             bogus: 1,
             normalize_was_called: true
           }

    assert VintageNet.get_configuration("bogus2") == %{
             type: VintageNetTest.TestTechnology,
             bogus: 2,
             normalize_was_called: true
           }
  end

  describe "resets interfaces to defaults" do
    test "already set to defaults" do
      path = Path.join(Application.get_env(:vintage_net, :persistence_dir), "bogus0")

      refute File.exists?(path)
      :ok = VintageNet.reset_to_defaults("bogus0")
      refute File.exists?(path)
      assert %{bogus: 0} = VintageNet.get_configuration("bogus0")
    end

    test "unconfigured in defaults" do
      path = Path.join(Application.get_env(:vintage_net, :persistence_dir), "bogus1")

      assert File.exists?(path)
      :ok = VintageNet.reset_to_defaults("bogus1")
      refute File.exists?(path)

      assert %{type: VintageNet.Technology.Null, reason: "No default configuration"} ==
               VintageNet.get_configuration("bogus1")
    end

    test "overridden by a configuration" do
      path = Path.join(Application.get_env(:vintage_net, :persistence_dir), "bogus2")

      assert File.exists?(path)
      :ok = VintageNet.reset_to_defaults("bogus2")
      refute File.exists?(path)
      # The default for bogus2 is -1
      assert %{bogus: -1} = VintageNet.get_configuration("bogus2")
    end

    test "unknown network interface" do
      path = Path.join(Application.get_env(:vintage_net, :persistence_dir), "unknown1")

      refute File.exists?(path)
      :ok = VintageNet.reset_to_defaults("unknown1")
      refute File.exists?(path)

      assert %{type: VintageNet.Technology.Null, reason: "No default configuration"} ==
               VintageNet.get_configuration("unknown1")
    end
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

    assert [
             {["available_interfaces"], []},
             {["connection"], :disconnected},
             {["name_servers"], []}
           ] ==
             VintageNet.match([:_])
  end

  test "verify system works", context do
    # create files here at some tmp place
    in_tmp(context.test, fn ->
      opts = Application.get_all_env(:vintage_net) |> prefix_paths(File.cwd!())

      File.mkdir!("sbin")
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
