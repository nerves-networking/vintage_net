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

  test "load a configuration from an earlier vintage_net version", context do
    in_tmp(context.test, fn ->
      persistence_dir = Application.get_env(:vintage_net, :persistence_dir)
      File.mkdir_p!(persistence_dir)

      File.write!(
        Path.join(persistence_dir, "eth0"),
        <<1, 100, 198, 145, 47, 223, 109, 197, 240, 63, 232, 187, 16, 90, 206, 44, 164, 88, 110,
          157, 4, 21, 106, 160, 247, 252, 75, 78, 111, 68, 229, 149, 37, 224, 216, 158, 11, 144,
          251, 156, 101, 93, 149, 176, 73, 116, 89, 69, 17, 103, 233, 24, 233, 193, 13, 146, 251,
          82, 239, 79, 81, 112, 252, 97, 81, 180, 190, 110, 195, 215, 14, 11, 50, 149, 32, 220,
          223, 78, 213, 91, 200, 95, 182, 24, 30, 206, 74, 57, 73, 37, 135, 141, 66, 219, 40, 192,
          223, 31, 234, 189, 149, 164, 111, 156, 129, 0, 212, 131, 102, 177, 24, 241, 114, 23,
          226, 50, 3, 143, 147, 134, 227, 255, 66, 186, 147, 241, 31, 105, 119, 151, 242, 196, 34,
          244, 158, 49, 79, 147>>
      )

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
