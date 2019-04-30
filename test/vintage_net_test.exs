defmodule VintageNetTest do
  use VintageNetTest.Case
  doctest VintageNet

  test "configure fails on bad technologies" do
    assert {:error, :type_missing} == VintageNet.configure("eth0", %{})
  end

  test "verify system works", context do
    # create files here at some tmp place
    in_tmp(context.test, fn ->
      opts = Application.get_all_env(:vintage_net) |> prefix_paths(File.cwd!())

      File.mkdir!("sbin")
      File.touch!("sbin/ifup")
      File.touch!("sbin/ifdown")
      assert :ok == VintageNet.verify_system(:ethernet, opts)
    end)
  end

  defp prefix_paths(opts, prefix) do
    Enum.map(opts, fn kv -> prefix_path(kv, prefix) end)
  end

  def prefix_path({key, path}, prefix) do
    key_str = to_string(key)

    if String.starts_with?(key_str, "bin_") do
      {key, prefix <> path}
    else
      {key, path}
    end
  end
end
