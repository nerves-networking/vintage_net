defmodule VintageNet.InterfaceTest do
  use VintageNetTest.Case
  alias VintageNet.Interface
  alias VintageNet.Interface.RawConfig
  import ExUnit.CaptureLog

  @ifname "test0"
  @interface_type VintageNetTest.TestTechnology

  setup do
    # Start clean slate for fresh InterfacesSupervisor each test.
    capture_log(fn ->
      Application.stop(:vintage_net)
      Application.start(:vintage_net)
    end)

    # Make the test interface available
    VintageNet.PropertyTable.put(VintageNet, ["interface", @ifname, "present"], true)
  end

  defp start_and_configure(raw_config, sleep_millis \\ 0, ifname \\ @ifname) do
    {:ok, _pid} = VintageNet.InterfacesSupervisor.start_interface(ifname)
    :ok = Interface.configure(raw_config)

    if sleep_millis do
      Process.sleep(sleep_millis)
    end

    assert :ok == Interface.wait_until_configured(ifname)
  end

  test "starting null interface", context do
    in_tmp(context.test, fn ->
      {:ok, raw_config} = VintageNet.Technology.Null.to_raw_config(@ifname)
      start_and_configure(raw_config)

      assert [@ifname] == VintageNet.configured_interfaces()
    end)
  end

  test "getting the configuration", context do
    in_tmp(context.test, fn ->
      {:ok, raw_config} = VintageNet.Technology.Null.to_raw_config(@ifname)
      start_and_configure(raw_config)

      assert %{type: VintageNet.Technology.Null} == VintageNet.get_configuration(@ifname)
    end)
  end

  test "creates and deletes files", context do
    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        type: @interface_type,
        files: [{"testing", "Hello, world"}]
      }

      start_and_configure(raw_config)

      assert VintageNet.get(["interface", @ifname, "type"]) == @interface_type
      assert File.exists?("testing")
      assert File.read!("testing") == "Hello, world"

      Interface.unconfigure(@ifname)
      assert :ok == Interface.wait_until_configured(@ifname)

      refute File.exists?("testing")
    end)
  end

  test "a missing interface won't run commands", context do
    in_tmp(context.test, fn ->
      # This assumes that ifname doesn't exist. Since we're requiring
      # it to exist before doing anything, the file should never be
      # created.
      ifname = "some_non_existent_interface0"

      raw_config = %RawConfig{
        ifname: ifname,
        type: @interface_type,
        files: [{"testing", "Hello, world"}],
        up_cmds: [],
        down_cmds: []
      }

      {:ok, _pid} = VintageNet.InterfacesSupervisor.start_interface(ifname)
      :ok = Interface.configure(raw_config)

      # It should be processed immediately. This is really just yielding
      Process.sleep(10)

      assert VintageNet.get(["interface", ifname, "type"]) == @interface_type
      refute File.exists?("testing")
    end)
  end

  test "a missing interface will run commands if not required", context do
    in_tmp(context.test, fn ->
      # This assumes that ifname doesn't exist.
      ifname = "some_non_existent_interface0"

      raw_config = %RawConfig{
        ifname: ifname,
        type: @interface_type,
        require_interface: false,
        files: [{"testing", "Hello, world"}],
        up_cmds: [],
        down_cmds: []
      }

      start_and_configure(raw_config, 0, ifname)

      assert File.exists?("testing")
    end)
  end

  test "create needed subdirectories", context do
    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        type: @interface_type,
        files: [{"one/two/three/testing", "Hello, world"}],
        up_cmds: [],
        down_cmds: []
      }

      start_and_configure(raw_config)

      assert File.exists?("one/two/three/testing")
      assert File.read!("one/two/three/testing") == "Hello, world"

      # Created directories don't need to be removed.
      Interface.unconfigure(@ifname)
      assert :ok == Interface.wait_until_configured(@ifname)
      refute File.exists?("one/two/three/testing")
    end)
  end

  test "can run commands", context do
    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        type: @interface_type,
        files: [],
        up_cmds: [{:run, "touch", ["i_am_configured"]}],
        down_cmds: [{:run, "rm", ["i_am_configured"]}]
      }

      start_and_configure(raw_config)

      assert File.exists?("i_am_configured")

      Interface.unconfigure(@ifname)
      assert :ok == Interface.wait_until_configured(@ifname)
      refute File.exists?("i_am_configured")
    end)
  end

  test "cleans up cleanup files", context do
    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        type: @interface_type,
        cleanup_files: ["i_am_configured"],
        up_cmds: [{:run, "touch", ["i_am_configured"]}]
      }

      start_and_configure(raw_config)

      assert File.exists?("i_am_configured")

      Interface.unconfigure(@ifname)
      assert :ok == Interface.wait_until_configured(@ifname)
      refute File.exists?("i_am_configured")
    end)
  end

  test "failed command retries", context do
    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        type: @interface_type,
        retry_millis: 10,
        files: [
          {"run.sh",
           """
           #!/bin/sh
           if [ -e first_try ]; then
             touch i_am_configured
           else
             # Fail the first time
             touch first_try
             exit 1
           fi
           """}
        ],
        up_cmds: [{:run, "sh", ["run.sh"]}],
        down_cmds: []
      }

      start_and_configure(raw_config, 250)

      assert File.exists?("i_am_configured")
    end)
  end

  test "hanging on configure command retries", context do
    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        type: @interface_type,
        retry_millis: 10,
        files: [
          {"run.sh",
           """
           #!/bin/sh
           if [ -e first_try ]; then
             touch i_am_configured
           else
             # Hang the first time
             touch first_try
             sleep 10000
           fi
           """}
        ],
        up_cmd_millis: 50,
        up_cmds: [{:run, "sh", ["run.sh"]}],
        down_cmds: []
      }

      start_and_configure(raw_config, 250)

      assert File.exists?("i_am_configured")
    end)
  end

  test "crash on configure command retries", context do
    crash_once = fn ->
      if File.exists?("i_crashed") do
        File.touch("i_am_configured")
        :ok
      else
        File.touch("i_crashed")
        raise "intentional oops"
      end
    end

    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        type: @interface_type,
        retry_millis: 10,
        up_cmd_millis: 50,
        up_cmds: [{:fun, crash_once}]
      }

      start_and_configure(raw_config, 250)

      assert File.exists?("i_crashed")
      assert File.exists?("i_am_configured")
    end)
  end

  test "hanging on unconfigure command recovers", context do
    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        type: @interface_type,
        retry_millis: 10,
        files: [{"hello", "world"}],
        down_cmd_millis: 50,
        down_cmds: [{:run, "sleep", ["100000"]}]
      }

      start_and_configure(raw_config)

      assert File.exists?("hello")

      assert :ok == Interface.unconfigure(@ifname)
      assert :ok == Interface.wait_until_configured(@ifname)

      refute File.exists?("hello")
    end)
  end

  test "reconfigure", context do
    in_tmp(context.test, fn ->
      raw_config1 = %RawConfig{
        ifname: @ifname,
        type: @interface_type,
        files: [{"first", ""}],
        up_cmds: [],
        down_cmds: [{:run, "touch", ["ran_first_down"]}]
      }

      raw_config2 = %RawConfig{
        ifname: @ifname,
        type: @interface_type,
        files: [{"second", ""}],
        up_cmds: [{:run, "touch", ["ran_second_up"]}],
        down_cmds: []
      }

      start_and_configure(raw_config1)

      assert File.exists?("first")

      assert :ok == Interface.configure(raw_config2)
      assert :ok == Interface.wait_until_configured(@ifname)

      refute File.exists?("first")
      assert File.exists?("ran_first_down")
      assert File.exists?("ran_second_up")
    end)
  end

  test "configure starts GenServers", context do
    in_tmp(context.test, fn ->
      us = self()

      raw_config = %RawConfig{
        ifname: @ifname,
        type: @interface_type,
        child_specs: [
          {Task,
           fn ->
             Process.register(self(), ItIsMe)
             send(us, :i_am_started)
             Process.sleep(1000)
           end}
        ]
      }

      start_and_configure(raw_config)

      assert_receive :i_am_started
      assert Process.whereis(ItIsMe) != nil

      assert :ok == Interface.unconfigure(@ifname)
      assert :ok == Interface.wait_until_configured(@ifname)

      assert Process.whereis(ItIsMe) == nil
    end)
  end

  test "ioctls fail when not configured", context do
    in_tmp(context.test, fn ->
      # Make a configuration that hangs in the :configuring state
      # so that it's easy to make an ioctl when not :configured.
      raw_config = %RawConfig{
        ifname: @ifname,
        type: @interface_type,
        up_cmd_millis: 10000,
        up_cmds: [{:run, "sleep", ["10000"]}]
      }

      start_and_configure(raw_config, 250)

      assert {:error, :unconfigured} == Interface.ioctl(@ifname, :a_command, [])
    end)
  end

  test "ioctls work when configured", context do
    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        type: @interface_type
      }

      start_and_configure(raw_config, 250)

      assert {:ok, :hello} == Interface.ioctl(@ifname, :echo, [:hello])
    end)
  end

  test "ioctl crashes are handled", context do
    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        type: @interface_type
      }

      start_and_configure(raw_config, 250)

      assert {:error, {:exit, _reason}} = Interface.ioctl(@ifname, :oops, [])
    end)
  end

  test "ioctls cancelled on reconfigure", context do
    in_tmp(context.test, fn ->
      raw_config1 = %RawConfig{
        ifname: @ifname,
        type: @interface_type
      }

      raw_config2 = %RawConfig{
        ifname: @ifname,
        type: @interface_type
      }

      start_and_configure(raw_config1)

      task = Task.async(fn -> Interface.ioctl(@ifname, :sleep, [10_000]) end)

      # Make sure that the task starts
      Process.sleep(10)

      assert :ok == Interface.configure(raw_config2)
      assert :ok == Interface.wait_until_configured(@ifname)

      assert {:error, :cancelled} = Task.await(task)
    end)
  end

  test "call configure during retry timeout", context do
    in_tmp(context.test, fn ->
      # Make the retry timeout really long
      raw_config1 = %RawConfig{
        ifname: @ifname,
        type: @interface_type,
        retry_millis: 100_000,
        up_cmds: [{:run, "false", []}]
      }

      raw_config2 = %RawConfig{
        ifname: @ifname,
        type: @interface_type
      }

      property = ["interface", @ifname, "state"]
      VintageNet.subscribe(property)

      {:ok, _pid} = VintageNet.InterfacesSupervisor.start_interface(@ifname)
      :ok = Interface.configure(raw_config1)

      assert_receive {VintageNet, property, _old_value, :retrying, _meta}

      assert :ok == Interface.configure(raw_config2)
      assert :ok == Interface.wait_until_configured(@ifname)
    end)
  end

  test "interface disappearing stops interface", context do
    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        type: @interface_type,
        files: [{"testing", "Hello, world"}]
      }

      start_and_configure(raw_config)

      assert File.exists?("testing")

      # "remove" the interface
      VintageNet.PropertyTable.clear(VintageNet, ["interface", @ifname, "present"])

      Process.sleep(10)

      refute File.exists?("testing")

      # bring the interface back
      VintageNet.PropertyTable.put(VintageNet, ["interface", @ifname, "present"], true)

      Process.sleep(10)

      assert File.exists?("testing")
    end)
  end
end
