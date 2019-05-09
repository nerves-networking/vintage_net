defmodule VintageNetTest do
  use VintageNetTest.Case
  doctest VintageNet

  import ExUnit.CaptureIO

  setup_all do
    Application.stop(:vintage_net)
    Application.start(:vintage_net)
  end

  test "configure fails on bad technologies" do
    assert {:error, :type_missing} == VintageNet.configure("eth0", %{})
  end

  test "interfaces exist" do
    interfaces = VintageNet.all_interfaces()

    # The loopback interface always exists, so check for it
    assert interfaces != []

    assert Enum.any?(interfaces, &String.starts_with?(&1, "lo"))
  end

  test "no interfaces are configured when testing" do
    assert [] == VintageNet.configured_interfaces()
  end

  test "info does something" do
    output = capture_io(&VintageNet.info/0)

    assert output =~ "All interfaces"
    assert output =~ "Available interfaces"
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
