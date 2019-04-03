defmodule VintageNet.ApplierTest do
  use VintageNetTest.Case
  alias VintageNet.Applier

  doctest Applier

  setup do
    # Fresh start each time.
    Application.stop(:vintage_net)
    Application.start(:vintage_net)
    :ok
  end

  test "applier can create and delete files", context do
    # create files here at some tmp place
    in_tmp(context.test, fn ->
      input = [{:bogonet0, %{files: [{"testing", "Hello, world"}], up_cmds: [], down_cmds: []}}]

      :ok = VintageNet.Applier.update_config(input)
      assert File.exists?("testing")
      assert File.read!("testing") == "Hello, world"

      :ok = VintageNet.Applier.update_config([])
      refute File.exists?("testing")
    end)
  end
end
