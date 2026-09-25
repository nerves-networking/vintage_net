# SPDX-FileCopyrightText: 2026 Cocoa Xu
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.PredictableInterfaceName.MatcherTest do
  use VintageNetTest.Case, async: true

  alias VintageNet.PredictableInterfaceName.Matcher

  doctest Matcher

  @hw_path "/devices/pci0000:00/0000:00:1c.4/0000:23:00.1"

  setup do
    sysfs = tmp_path(:matcher_sysfs)
    File.rm_rf!(sysfs)

    device_dir = Path.join(sysfs, @hw_path)
    File.mkdir_p!(Path.join(device_dir, "net/enp35s0f1"))
    File.mkdir_p!(Path.join(sysfs, "bus/pci/drivers/ixgbe"))
    File.mkdir_p!(Path.join(sysfs, "bus/pci/drivers/pcieport"))
    File.ln_s!(Path.join(sysfs, "bus/pci/drivers/ixgbe"), Path.join(device_dir, "driver"))

    File.ln_s!(
      Path.join(sysfs, "bus/pci/drivers/pcieport"),
      Path.join(Path.dirname(device_dir), "driver")
    )

    File.mkdir_p!(Path.join(sysfs, "class/net"))
    File.ln_s!(Path.join(device_dir, "net/enp35s0f1"), Path.join(sysfs, "class/net/enp35s0f1"))
    File.write!(Path.join(device_dir, "net/enp35s0f1/address"), "1c:86:0b:12:34:56\n")

    %{sysfs: sysfs}
  end

  test "reads the device and its parents from sysfs", %{sysfs: sysfs} do
    assert Matcher.device("enp35s0f1", @hw_path, sysfs) == %{
             hw_path: @hw_path,
             kernels: ["pci0000:00", "0000:00:1c.4", "0000:23:00.1"],
             drivers: ["ixgbe", "pcieport"],
             mac: "1c:86:0b:12:34:56"
           }
  end

  test "an interface that is gone matches nothing but hw_path", %{sysfs: sysfs} do
    device = Matcher.device("gone0", "/devices/platform/gone", sysfs)

    assert device.drivers == []
    assert device.mac == nil
    refute Matcher.matches?(%{ifname: "x", mac: "*"}, device)
    assert Matcher.matches?(%{ifname: "x", hw_path: "/devices/platform/*"}, device)
  end

  test "every key in a rule has to match", %{sysfs: sysfs} do
    device = Matcher.device("enp35s0f1", @hw_path, sysfs)

    assert Matcher.matches?(%{ifname: "ethdev1", drivers: "ixgbe", mac: "1c:86:0b:*"}, device)
    refute Matcher.matches?(%{ifname: "ethdev1", mac: "1C:86:0B:*"}, device)
    refute Matcher.matches?(%{ifname: "ethdev1", drivers: "ixgbe", mac: "a0:10:a2:*"}, device)
    assert Matcher.matches?(%{ifname: "ethdev1", drivers: ["igb", "ixgbe"]}, device)
    assert Matcher.matches?(%{ifname: "ethdev1", kernels: "0000:23:00.?"}, device)
  end

  test "regexes match as given", %{sysfs: sysfs} do
    device = Matcher.device("enp35s0f1", @hw_path, sysfs)

    assert Matcher.matches?(%{ifname: "ethdev1", kernels: ~r/^0000:(0b|23|29):00\.1$/}, device)
    assert Matcher.matches?(%{ifname: "ethdev1", mac: {:regex, "^1c:86:0b"}}, device)
    refute Matcher.matches?(%{ifname: "ethdev1", mac: {:regex, "^1C:86:0B"}}, device)
    assert Matcher.matches?(%{ifname: "ethdev1", mac: ~r/^1C:86:0B/i}, device)
    assert Matcher.matches?(%{ifname: "ethdev1", drivers: ["igb", ~r/^ixgbe$/]}, device)
  end

  test "a rule without match keys matches nothing", %{sysfs: sysfs} do
    refute Matcher.matches?(%{ifname: "lan0"}, Matcher.device("enp35s0f1", @hw_path, sysfs))
  end
end
