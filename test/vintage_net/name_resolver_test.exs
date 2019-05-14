defmodule VintageNet.Interface.NameResolverTest do
  use VintageNetTest.Case
  alias VintageNet.NameResolver
  import ExUnit.CaptureLog

  @resolvconf_path "resolv.conf"

  setup do
    # Run the tests with the application stopped.
    capture_log(fn ->
      Application.stop(:vintage_net)
    end)

    on_exit(fn -> Application.start(:vintage_net) end)
    :ok
  end

  test "empty resolvconf is empty", context do
    in_tmp(context.test, fn ->
      NameResolver.start_link(resolvconf: @resolvconf_path)
      assert File.exists?(@resolvconf_path)
      assert File.read!(@resolvconf_path) == ""
      NameResolver.stop()
    end)
  end

  test "adding one interface", context do
    in_tmp(context.test, fn ->
      NameResolver.start_link(resolvconf: @resolvconf_path)
      NameResolver.setup("eth0", "example.com", ["1.1.1.1", "8.8.8.8"])

      contents = File.read!(@resolvconf_path)

      assert contents == """
             search example.com
             nameserver 1.1.1.1
             nameserver 8.8.8.8
             """

      NameResolver.clear("eth0")
      contents = File.read!(@resolvconf_path)
      assert contents == ""

      NameResolver.stop()
    end)
  end

  test "adding two interfaces", context do
    in_tmp(context.test, fn ->
      NameResolver.start_link(resolvconf: @resolvconf_path)
      NameResolver.setup("eth0", "example.com", ["1.1.1.1", "8.8.8.8"])
      NameResolver.setup("wlan0", "example2.com", ["1.1.1.2", "8.8.8.9"])

      contents = File.read!(@resolvconf_path)

      assert contents == """
             search example.com
             search example2.com
             nameserver 1.1.1.1
             nameserver 8.8.8.8
             nameserver 1.1.1.2
             nameserver 8.8.8.9
             """

      NameResolver.clear("eth0")
      contents = File.read!(@resolvconf_path)

      assert contents == """
             search example2.com
             nameserver 1.1.1.2
             nameserver 8.8.8.9
             """

      NameResolver.stop()
    end)
  end

  test "clearing all interfaces", context do
    in_tmp(context.test, fn ->
      NameResolver.start_link(resolvconf: @resolvconf_path)
      NameResolver.setup("eth0", "example.com", ["1.1.1.1", "8.8.8.8"])
      NameResolver.setup("wlan0", "example2.com", ["1.1.1.2", "8.8.8.9"])
      NameResolver.clear_all()
      assert File.read!(@resolvconf_path) == ""
      NameResolver.stop()
    end)
  end
end
