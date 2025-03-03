# SPDX-FileCopyrightText: 2023 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.TechnologyTest do
  use ExUnit.Case
  alias VintageNet.Technology

  test "loading good configurations" do
    assert VintageNetTest.TestTechnology ==
             Technology.module_from_config!(%{
               type: VintageNetTest.TestTechnology,
               bogus: 0
             })
  end
end
