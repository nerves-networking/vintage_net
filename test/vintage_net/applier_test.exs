defmodule VintageNet.ApplierTest do
  use VintageNetTest.Case
  # alias VintageNet.Applier

  #  doctest Applier

  setup do
    # Fresh start each time.
    Application.stop(:vintage_net)
    Application.start(:vintage_net)
    :ok
  end

  test "applier can create and delete files", context do
    # in_tmp(context.test, fn ->
    #   input = [{:bogonet0, %{files: [{"testing", "Hello, world"}], up_cmds: [], down_cmds: []}}]

    #   :ok = VintageNet.Applier.update_config(input)
    #   assert File.exists?("testing")
    #   assert File.read!("testing") == "Hello, world"

    #   :ok = VintageNet.Applier.update_config([])
    #   refute File.exists?("testing")
    # end)
  end

  test "applier can create needed subdirectories", context do
    # in_tmp(context.test, fn ->
    #   input = [
    #     {:bogonet0,
    #      %{files: [{"one/two/three/testing", "Hello, world"}], up_cmds: [], down_cmds: []}}
    #   ]

    #   :ok = VintageNet.Applier.update_config(input)
    #   assert File.exists?("one/two/three/testing")
    #   assert File.read!("one/two/three/testing") == "Hello, world"

    #   # Created directories don't need to be removed.
    #   :ok = VintageNet.Applier.update_config([])
    #   refute File.exists?("one/two/three/testing")
    # end)
  end

  test "applier can run commands", context do
    #   in_tmp(context.test, fn ->
    #     input = [
    #       {:bogonet0,
    #        %{
    #          files: [],
    #          up_cmds: [{:run, "touch", ["test_file"]}],
    #          down_cmds: [{:run, "rm", ["test_file"]}]
    #        }}
    #     ]

    #     :ok = VintageNet.Applier.update_config(input)
    #     assert File.exists?("test_file")

    #     :ok = VintageNet.Applier.update_config([])
    #     refute File.exists?("test_file")
    #   end)
  end
end
