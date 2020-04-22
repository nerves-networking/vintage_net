defmodule VintageNet.InterfaceTest do
  use VintageNetTest.Case
  alias VintageNet.Interface
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

  defp configure_only(config, ifname \\ @ifname) do
    {:ok, _pid} = VintageNet.InterfacesSupervisor.start_interface(ifname)
    :ok = Interface.configure(ifname, config)
  end

  defp configure_and_wait(config, sleep_millis \\ 0, ifname \\ @ifname) do
    {:ok, _pid} = VintageNet.InterfacesSupervisor.start_interface(ifname)
    :ok = Interface.configure(ifname, config)

    if sleep_millis do
      Process.sleep(sleep_millis)
    end

    assert :ok == Interface.wait_until_configured(ifname)
  end

  test "starting null interface", context do
    capture_log_in_tmp(context.test, fn ->
      config = %{type: VintageNet.Technology.Null}
      configure_and_wait(config)

      refute @ifname in VintageNet.configured_interfaces()
    end)
  end

  test "deconfigure uses null type", context do
    capture_log_in_tmp(context.test, fn ->
      config = %{type: @interface_type}

      configure_and_wait(config)
      assert @ifname in VintageNet.configured_interfaces()
      :ok = VintageNet.deconfigure(@ifname)
      assert %{type: VintageNet.Technology.Null} == VintageNet.get_configuration(@ifname)

      :ok = Interface.wait_until_configured(@ifname)
      refute @ifname in VintageNet.configured_interfaces()
    end)
  end

  test "getting the configuration", context do
    capture_log_in_tmp(context.test, fn ->
      config = %{type: @interface_type}
      configure_and_wait(config)

      assert %{type: @interface_type, normalize_was_called: true} ==
               VintageNet.get_configuration(@ifname)
    end)
  end

  test "creates and deletes files", context do
    capture_log_in_tmp(context.test, fn ->
      config = %{
        type: @interface_type,
        files: [{"testing", "Hello, world"}]
      }

      configure_and_wait(config)

      assert VintageNet.get(["interface", @ifname, "type"]) == @interface_type
      assert File.exists?("testing")
      assert File.read!("testing") == "Hello, world"

      :ok = Interface.deconfigure(@ifname)
      assert :ok == Interface.wait_until_configured(@ifname)

      refute File.exists?("testing")
    end)
  end

  test "a missing interface won't run commands", context do
    capture_log_in_tmp(context.test, fn ->
      # This assumes that ifname doesn't exist. Since we're requiring
      # it to exist before doing anything, the file should never be
      # created.
      ifname = "some_non_existent_interface0"

      config = %{
        type: @interface_type,
        files: [{"testing", "Hello, world"}]
      }

      {:ok, _pid} = VintageNet.InterfacesSupervisor.start_interface(ifname)
      :ok = Interface.configure(ifname, config)

      # It should be processed immediately. This is really just yielding
      Process.sleep(10)

      assert VintageNet.get(["interface", ifname, "type"]) == @interface_type
      refute File.exists?("testing")
    end)
  end

  test "a missing interface will run commands if not required", context do
    capture_log_in_tmp(context.test, fn ->
      # This assumes that ifname doesn't exist.
      ifname = "some_non_existent_interface0"

      config = %{
        type: @interface_type,
        required_ifnames: [],
        files: [{"testing", "Hello, world"}]
      }

      configure_and_wait(config, 0, ifname)

      assert File.exists?("testing")
    end)
  end

  test "create needed subdirectories", context do
    capture_log_in_tmp(context.test, fn ->
      config = %{
        type: @interface_type,
        files: [{"one/two/three/testing", "Hello, world"}]
      }

      configure_and_wait(config)

      assert File.exists?("one/two/three/testing")
      assert File.read!("one/two/three/testing") == "Hello, world"

      # Created directories don't need to be removed.
      Interface.deconfigure(@ifname)
      assert :ok == Interface.wait_until_configured(@ifname)
      refute File.exists?("one/two/three/testing")
    end)
  end

  test "can run commands", context do
    capture_log_in_tmp(context.test, fn ->
      config = %{
        type: @interface_type,
        up_cmds: [{:run, "touch", ["i_am_configured"]}],
        down_cmds: [{:run, "rm", ["i_am_configured"]}]
      }

      configure_and_wait(config)

      assert File.exists?("i_am_configured")

      :ok = Interface.deconfigure(@ifname)
      assert :ok == Interface.wait_until_configured(@ifname)
      refute File.exists?("i_am_configured")
    end)
  end

  test "cleans up cleanup files", context do
    capture_log_in_tmp(context.test, fn ->
      config = %{
        type: @interface_type,
        cleanup_files: ["i_am_configured"],
        up_cmds: [{:run, "touch", ["i_am_configured"]}]
      }

      configure_and_wait(config)

      assert File.exists?("i_am_configured")

      :ok = Interface.deconfigure(@ifname)
      assert :ok == Interface.wait_until_configured(@ifname)
      refute File.exists?("i_am_configured")
    end)
  end

  test "failed command retries", context do
    log =
      capture_log_in_tmp(context.test, fn ->
        config = %{
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

        configure_and_wait(config, 250)

        assert File.exists?("i_am_configured")
      end)

    # Check that the error was logged.
    assert log =~ "[error] Nonzero exit from sh"
  end

  test "hanging on configure command retries", context do
    log =
      capture_log_in_tmp(context.test, fn ->
        config = %{
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
               /bin/sleep 10000
               echo "Should not get here"
             fi
             """}
          ],
          up_cmd_millis: 50,
          up_cmds: [{:run, "sh", ["run.sh"]}],
          down_cmds: []
        }

        configure_and_wait(config, 250)

        assert File.exists?("i_am_configured")
      end)

    # Check that the error was logged.
    assert log =~ "recovering from hang"
    refute log =~ "Should not get here"
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

    log =
      capture_log_in_tmp(context.test, fn ->
        config = %{
          type: @interface_type,
          retry_millis: 10,
          up_cmd_millis: 50,
          up_cmds: [{:fun, crash_once}]
        }

        configure_and_wait(config, 250)

        assert File.exists?("i_crashed")
        assert File.exists?("i_am_configured")
      end)

    assert log =~ "(RuntimeError) intentional oops"
  end

  test "hanging on deconfigure command recovers", context do
    log =
      capture_log_in_tmp(context.test, fn ->
        config = %{
          type: @interface_type,
          retry_millis: 10,
          files: [{"hello", "world"}],
          down_cmd_millis: 50,
          down_cmds: [{:run, "sleep", ["100000"]}]
        }

        configure_and_wait(config)

        assert File.exists?("hello")

        assert :ok == Interface.deconfigure(@ifname)
        assert :ok == Interface.wait_until_configured(@ifname)

        refute File.exists?("hello")
      end)

    assert log =~ "recovering from hang"
  end

  test "reconfigure", context do
    capture_log_in_tmp(context.test, fn ->
      config1 = %{
        type: @interface_type,
        files: [{"first", ""}],
        up_cmds: [],
        down_cmds: [{:run, "touch", ["ran_first_down"]}]
      }

      config2 = %{
        type: @interface_type,
        source_config: %{},
        files: [{"second", ""}],
        up_cmds: [{:run, "touch", ["ran_second_up"]}],
        down_cmds: []
      }

      configure_and_wait(config1)

      assert File.exists?("first")

      assert :ok == Interface.configure(@ifname, config2)
      assert :ok == Interface.wait_until_configured(@ifname)

      refute File.exists?("first")
      assert File.exists?("ran_first_down")
      assert File.exists?("ran_second_up")
    end)
  end

  test "configuring while configuring command", context do
    capture_log_in_tmp(context.test, fn ->
      # Start configuring the first one - it will hang
      config = %{
        type: @interface_type,
        files: [{"first_config", ""}],
        up_cmds: [{:run, "sleep", ["60"]}]
      }

      configure_only(config)

      # Make sure that everything is started before interrupting.
      # I'm not sure this is even necessary, but it's more like what
      # happens in the wild.
      Process.sleep(100)

      # Configure the second one - it should interrupt the first
      config2 = %{
        type: @interface_type,
        files: [{"second_config", ""}],
        up_cmds: [{:run, "touch", ["did_it"]}]
      }

      :ok = Interface.configure(@ifname, config2)

      assert :ok == Interface.wait_until_configured(@ifname)

      refute File.exists?("first_config")
      assert File.exists?("second_config")
      assert File.exists?("did_it")
    end)
  end

  test "configure starts GenServers", context do
    capture_log_in_tmp(context.test, fn ->
      us = self()

      config = %{
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

      configure_and_wait(config)

      assert_receive :i_am_started
      assert Process.whereis(ItIsMe) != nil

      assert :ok == Interface.deconfigure(@ifname)
      assert :ok == Interface.wait_until_configured(@ifname)

      assert Process.whereis(ItIsMe) == nil
    end)
  end

  test "GenServers from technology stop when interface disappears", context do
    capture_log_in_tmp(context.test, fn ->
      us = self()

      config = %{
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

      configure_and_wait(config)

      assert_receive :i_am_started
      assert Process.whereis(ItIsMe) != nil

      # "remove" the interface
      VintageNet.PropertyTable.clear(VintageNet, ["interface", @ifname, "present"])

      Process.sleep(10)

      assert Process.whereis(ItIsMe) == nil

      # bring the interface back and it should start again
      VintageNet.PropertyTable.put(VintageNet, ["interface", @ifname, "present"], true)

      assert_receive :i_am_started
      assert Process.whereis(ItIsMe) != nil
    end)
  end

  test "ioctls fail when not configured", context do
    log =
      capture_log_in_tmp(context.test, fn ->
        # Make a configuration that hangs in the :configuring state
        # so that it's easy to make an ioctl when not :configured.
        config = %{
          type: @interface_type,
          up_cmd_millis: 10000,
          up_cmds: [{:run, "sleep", ["10000"]}]
        }

        configure_only(config)
        Process.sleep(250)

        assert {:error, :unconfigured} == Interface.ioctl(@ifname, :a_command, [])
      end)

    assert log =~ "call ioctl (returning error)"
  end

  test "ioctls work when configured", context do
    capture_log_in_tmp(context.test, fn ->
      config = %{type: @interface_type}

      configure_and_wait(config)

      assert {:ok, :hello} == Interface.ioctl(@ifname, :echo, [:hello])
    end)
  end

  test "ioctl crashes are handled", context do
    log =
      capture_log_in_tmp(context.test, fn ->
        config = %{type: @interface_type}

        configure_and_wait(config)

        assert {:error, {:exit, _reason}} = Interface.ioctl(@ifname, :oops, [])
      end)

    assert log =~ "(RuntimeError) Intentional ioctl oops"
  end

  test "ioctls cancelled on reconfigure", context do
    capture_log_in_tmp(context.test, fn ->
      config1 = %{type: @interface_type, id: 1}
      config2 = %{type: @interface_type, id: 2}

      configure_and_wait(config1)

      task = Task.async(fn -> Interface.ioctl(@ifname, :sleep, [10_000]) end)

      # Make sure that the task starts
      Process.sleep(10)

      assert :ok == Interface.configure(@ifname, config2)
      assert :ok == Interface.wait_until_configured(@ifname)

      assert {:error, :cancelled} = Task.await(task)
    end)
  end

  test "call configure during retry timeout", context do
    capture_log_in_tmp(context.test, fn ->
      # Make the retry timeout really long
      config1 = %{
        type: @interface_type,
        retry_millis: 100_000,
        up_cmds: [{:run, "false", []}]
      }

      config2 = %{type: @interface_type}

      property = ["interface", @ifname, "state"]
      VintageNet.subscribe(property)

      configure_only(config1)

      assert_receive {VintageNet, property, _old_value, :retrying, _meta}

      assert :ok == Interface.configure(@ifname, config2)
      assert :ok == Interface.wait_until_configured(@ifname)
    end)
  end

  test "interface disappearing stops interface", context do
    capture_log_in_tmp(context.test, fn ->
      config = %{
        type: @interface_type,
        files: [{"testing", "Hello, world"}]
      }

      configure_and_wait(config)

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

  test "interface starts when all dependent ifnames are present", context do
    capture_log_in_tmp(context.test, fn ->
      config = %{
        type: @interface_type,
        files: [{"testing", "Hello, world"}],
        required_ifnames: ["test1", "test2"]
      }

      configure_only(config)

      Process.sleep(10)

      refute File.exists?("testing")

      # Add one dependent
      VintageNet.PropertyTable.put(VintageNet, ["interface", "test1", "present"], true)

      Process.sleep(10)

      refute File.exists?("testing")

      # Add the other dependent
      VintageNet.PropertyTable.put(VintageNet, ["interface", "test2", "present"], true)

      Process.sleep(10)

      assert File.exists?("testing")

      # clean up
      VintageNet.PropertyTable.clear(VintageNet, ["interface", "test1", "present"])
      VintageNet.PropertyTable.clear(VintageNet, ["interface", "test2", "present"])
    end)
  end

  test "interface stops when any dependent ifname goes away", context do
    capture_log_in_tmp(context.test, fn ->
      config = %{
        type: @interface_type,
        files: [{"testing", "Hello, world"}],
        required_ifnames: ["test1", "test2"]
      }

      VintageNet.PropertyTable.put(VintageNet, ["interface", "test1", "present"], true)
      VintageNet.PropertyTable.put(VintageNet, ["interface", "test2", "present"], true)

      configure_and_wait(config)

      assert File.exists?("testing")

      # "remove" one interface
      VintageNet.PropertyTable.clear(VintageNet, ["interface", "test2", "present"])

      Process.sleep(10)

      refute File.exists?("testing")

      # bring the interface back
      VintageNet.PropertyTable.put(VintageNet, ["interface", "test2", "present"], true)

      Process.sleep(10)

      assert File.exists?("testing")

      # "remove" the other interface
      VintageNet.PropertyTable.clear(VintageNet, ["interface", "test1", "present"])

      Process.sleep(10)

      refute File.exists?("testing")

      # bring the interface back
      VintageNet.PropertyTable.put(VintageNet, ["interface", "test1", "present"], true)

      Process.sleep(10)

      assert File.exists?("testing")

      # "removing" the base interface doesn't do anything since it's not required
      VintageNet.PropertyTable.clear(VintageNet, ["interface", @ifname, "present"])

      Process.sleep(10)

      assert File.exists?("testing")

      # bring the interface back
      VintageNet.PropertyTable.put(VintageNet, ["interface", @ifname, "present"], true)

      Process.sleep(10)

      assert File.exists?("testing")

      # clean up
      VintageNet.PropertyTable.clear(VintageNet, ["interface", "test1", "present"])
      VintageNet.PropertyTable.clear(VintageNet, ["interface", "test2", "present"])
    end)
  end
end
