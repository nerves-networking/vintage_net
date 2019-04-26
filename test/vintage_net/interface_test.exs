defmodule VintageNet.ApplierTest do
  use VintageNetTest.Case
  alias VintageNet.Interface
  alias VintageNet.Interface.RawConfig

  @ifname "test0"

  test "creates and deletes files", context do
    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        files: [{"testing", "Hello, world"}],
        up_cmds: [],
        down_cmds: []
      }

      {:ok, _pid} = Interface.start_link(ifname: @ifname, config: raw_config)
      assert :ok == Interface.wait_until_configured(@ifname)

      assert File.exists?("testing")
      assert File.read!("testing") == "Hello, world"

      Interface.unconfigure(@ifname)
      assert :ok == Interface.wait_until_configured(@ifname)

      refute File.exists?("testing")
    end)
  end

  test "create needed subdirectories", context do
    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        files: [{"one/two/three/testing", "Hello, world"}],
        up_cmds: [],
        down_cmds: []
      }

      {:ok, _pid} = Interface.start_link(ifname: @ifname, config: raw_config)
      assert :ok == Interface.wait_until_configured(@ifname)

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
        files: [],
        up_cmds: [{:run, "touch", ["i_am_configured"]}],
        down_cmds: [{:run, "rm", ["i_am_configured"]}]
      }

      {:ok, _pid} = Interface.start_link(ifname: @ifname, config: raw_config)
      assert :ok == Interface.wait_until_configured(@ifname)

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
        retry_millis: 10,
        files: [
          {"doit.sh",
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
        up_cmds: [{:run, "sh", ["doit.sh"]}],
        down_cmds: []
      }

      {:ok, _pid} = Interface.start_link(ifname: @ifname, config: raw_config)
      Process.sleep(250)
      assert :ok == Interface.wait_until_configured(@ifname)

      assert File.exists?("i_am_configured")
    end)
  end

  test "hanging on configure command retries", context do
    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        retry_millis: 10,
        files: [
          {"doit.sh",
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
        up_cmds: [{:run, "sh", ["doit.sh"]}],
        down_cmds: []
      }

      {:ok, _pid} = Interface.start_link(ifname: @ifname, config: raw_config)
      Process.sleep(250)
      assert :ok == Interface.wait_until_configured(@ifname)

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
        retry_millis: 10,
        files: [],
        up_cmd_millis: 50,
        up_cmds: [{:fun, crash_once}],
        down_cmds: []
      }

      {:ok, _pid} = Interface.start_link(ifname: @ifname, config: raw_config)
      Process.sleep(250)
      assert :ok == Interface.wait_until_configured(@ifname)

      assert File.exists?("i_crashed")
      assert File.exists?("i_am_configured")
    end)
  end

  test "hanging on unconfigure command recovers", context do
    in_tmp(context.test, fn ->
      raw_config = %RawConfig{
        ifname: @ifname,
        retry_millis: 10,
        files: [{"hello", "world"}],
        up_cmd_millis: 50,
        up_cmds: [],
        down_cmd_millis: 50,
        down_cmds: [{:run, "sleep", ["100000"]}]
      }

      {:ok, _pid} = Interface.start_link(ifname: @ifname, config: raw_config)
      assert :ok == Interface.wait_until_configured(@ifname)

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
        files: [{"first", ""}],
        up_cmds: [],
        down_cmds: [{:run, "touch", ["ran_first_down"]}]
      }

      raw_config2 = %RawConfig{
        ifname: @ifname,
        files: [{"second", ""}],
        up_cmds: [{:run, "touch", ["ran_second_up"]}],
        down_cmds: []
      }

      {:ok, _pid} = Interface.start_link(ifname: @ifname, config: raw_config1)
      assert :ok == Interface.wait_until_configured(@ifname)

      assert File.exists?("first")

      assert :ok == Interface.configure(@ifname, raw_config2)
      assert :ok == Interface.wait_until_configured(@ifname)

      refute File.exists?("first")
      assert File.exists?("ran_first_down")
      assert File.exists?("ran_second_up")
    end)
  end
end
