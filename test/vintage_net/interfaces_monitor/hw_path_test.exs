# SPDX-FileCopyrightText: 2020 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.InterfacesMonitor.HWPathTest do
  use ExUnit.Case
  doctest VintageNet.InterfacesMonitor.HWPath
  alias VintageNet.InterfacesMonitor.HWPath

  test "normalizes path" do
    assert "/devices/pci0000:00/0000:00:01.1/0000:01:00.2/0000:02:04.0/0000:04:00.0" ==
             HWPath.symlink_to_hw_path(
               "../../devices/pci0000:00/0000:00:01.1/0000:01:00.2/0000:02:04.0/0000:04:00.0/net/enp4s0",
               "enp4s0"
             )

    assert "/devices/virtual" ==
             HWPath.symlink_to_hw_path("../../devices/virtual/net/lo", "lo")

    assert "/devices/platform/scb/fd580000.genet" ==
             HWPath.symlink_to_hw_path(
               "../../devices/platform/scb/fd580000.genet/net/eth0",
               "eth0"
             )

    assert "/devices/platform/soc/fe300000.mmcnr/mmc_host/mmc1/mmc1:0001/mmc1:0001:1" ==
             HWPath.symlink_to_hw_path(
               "../../devices/platform/soc/fe300000.mmcnr/mmc_host/mmc1/mmc1:0001/mmc1:0001:1/net/wlan0",
               "wlan0"
             )
  end

  test "returns input if unexpected" do
    assert "/unexpected" == HWPath.symlink_to_hw_path("/unexpected", "enp4s0")
  end
end
