defmodule VintageNet.ApplierTest do
  use VintageNetTest.Case
  alias VintageNet.Interface2
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

      {:ok, _pid} = Interface2.start_link(ifname: @ifname, config: raw_config)
      assert :ok == Interface2.wait_until_configured(@ifname)

      assert File.exists?("testing")
      assert File.read!("testing") == "Hello, world"

      Interface2.unconfigure(@ifname)
      assert :ok == Interface2.wait_until_configured(@ifname)

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

      {:ok, _pid} = Interface2.start_link(ifname: @ifname, config: raw_config)
      assert :ok == Interface2.wait_until_configured(@ifname)

      assert File.exists?("one/two/three/testing")
      assert File.read!("one/two/three/testing") == "Hello, world"

      # Created directories don't need to be removed.
      Interface2.unconfigure(@ifname)
      assert :ok == Interface2.wait_until_configured(@ifname)
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

      {:ok, _pid} = Interface2.start_link(ifname: @ifname, config: raw_config)
      assert :ok == Interface2.wait_until_configured(@ifname)

      assert File.exists?("i_am_configured")

      Interface2.unconfigure(@ifname)
      assert :ok == Interface2.wait_until_configured(@ifname)
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

      {:ok, _pid} = Interface2.start_link(ifname: @ifname, config: raw_config)
      Process.sleep(250)
      assert :ok == Interface2.wait_until_configured(@ifname)

      assert File.exists?("i_am_configured")
    end)
  end

  test "hanging command retries", context do
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

      {:ok, _pid} = Interface2.start_link(ifname: @ifname, config: raw_config)
      Process.sleep(250)
      assert :ok == Interface2.wait_until_configured(@ifname)

      assert File.exists?("i_am_configured")
    end)
  end
end
