# SPDX-FileCopyrightText: 2019 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.Technology.NullTest do
  use ExUnit.Case
  alias VintageNet.Interface.RawConfig
  alias VintageNet.Technology.Null

  test "normalizing null" do
    # Normalizing anything to Null should be Null
    assert %{type: VintageNet.Technology.Null, reason: ""} == Null.normalize(%{})
  end

  test "converting to raw config" do
    input = %{
      type: VintageNet.Technology.Null,
      reason: "unit testing"
    }

    # Static IP support is not implemented. This is what is currently produced,
    # but it is incomplete.
    output = %RawConfig{
      type: VintageNet.Technology.Null,
      ifname: "eth0",
      source_config: input,
      required_ifnames: []
    }

    assert output == Null.to_raw_config("eth0", input, [])
  end
end
