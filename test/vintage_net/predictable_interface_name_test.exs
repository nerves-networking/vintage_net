defmodule VintageNet.PredictableInterfaceNameTest do
  use ExUnit.Case
  alias VintageNet.PredictableInterfaceName

  @tag :requires_interfaces_monitor
  @tag :sudo
  test "interface gets renamed" do
    unpredictable_ifname = "unpredictable0"
    predictable_ifname = "predictable0"
    ensure_fake_ifs_removed([unpredictable_ifname, predictable_ifname])

    config = %{
      hw_path: "/devices/virtual",
      ifname: "predictable0"
    }

    VintageNet.subscribe(["interface", "predictable0", "present"])

    start_supervised!({PredictableInterfaceName, [config]})

    :ok = bring_up_fake_if(unpredictable_ifname)
    Process.sleep(2000)
    assert_receive {VintageNet, ["interface", "predictable0", "present"], nil, true, %{}}

    ensure_fake_ifs_removed([unpredictable_ifname, predictable_ifname])
  end

  defp ensure_fake_ifs_removed(ifnames) do
    elevate_user()

    for ifname <- ifnames do
      System.cmd("sudo", ["ip", "link", "del", ifname])
    end
  end

  defp bring_up_fake_if(ifname) do
    elevate_user()
    System.cmd("sudo", ["ip", "link", "add", ifname, "type", "dummy"])
    :ok
  end

  def elevate_user() do
    ask_pass = System.get_env("SUDO_ASKPASS") || "/usr/bin/ssh-askpass"
    System.put_env("SUDO_ASKPASS", ask_pass)
  end
end
