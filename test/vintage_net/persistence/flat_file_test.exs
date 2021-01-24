defmodule VintageNet.Persistence.FlatFileTest do
  use VintageNetTest.Case
  alias VintageNet.Persistence.FlatFile

  @config %{
    type: VintageNetTest.TestTechnology,
    ipv4: %{method: :dhcp},
    hostname: "unit_test"
  }

  test "saves and loads configurations", context do
    in_tmp(context.test, fn ->
      FlatFile.save("eth0", @config)

      assert {:ok, @config} = FlatFile.load("eth0")
    end)
  end

  test "unknown configurations return error", context do
    in_tmp(context.test, fn ->
      assert {:error, _} = FlatFile.load("eth0")
    end)
  end

  test "corrupt configurations return error", context do
    in_tmp(context.test, fn ->
      FlatFile.save("eth0", @config)

      persistence_dir = Application.get_env(:vintage_net, :persistence_dir)
      eth0_path = Path.join(persistence_dir, "eth0")
      <<version, _oops, contents::binary>> = File.read!(eth0_path)
      File.write!(eth0_path, [<<version>>, contents])

      assert {:error, _} = FlatFile.load("eth0")
    end)
  end

  test "bad secrets return error", context do
    in_tmp(context.test, fn ->
      original_key = Application.get_env(:vintage_net, :persistence_secret)

      FlatFile.save("eth0", @config)
      Application.put_env(:vintage_net, :persistence_secret, "1234567890123456")
      assert {:error, :decryption_failed} = FlatFile.load("eth0")

      Application.put_env(:vintage_net, :persistence_secret, original_key)
    end)
  end

  test "using an MFA for getting the secret key", context do
    in_tmp(context.test, fn ->
      original_key = Application.get_env(:vintage_net, :persistence_secret)

      Application.put_env(:vintage_net, :persistence_secret, {__MODULE__, :get_secret, []})
      FlatFile.save("eth0", @config)
      assert {:ok, @config} = FlatFile.load("eth0")

      Application.put_env(:vintage_net, :persistence_secret, original_key)
      assert {:error, :decryption_failed} = FlatFile.load("eth0")
    end)
  end

  def get_secret() do
    "my_super_secret_"
  end

  test "enumerates known interfaces", context do
    in_tmp(context.test, fn ->
      assert [] == FlatFile.enumerate()

      FlatFile.save("eth0", @config)

      assert ["eth0"] == FlatFile.enumerate()

      FlatFile.save("wlan0", @config)

      assert ["eth0", "wlan0"] == FlatFile.enumerate()

      FlatFile.clear("eth0")

      assert ["wlan0"] == FlatFile.enumerate()
    end)
  end
end
