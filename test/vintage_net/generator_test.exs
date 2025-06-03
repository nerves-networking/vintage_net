# SPDX-FileCopyrightText: 2025 Jonatan Männchen
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.GeneratorTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  alias Igniter.Code.Common, as: CodeCommon
  alias Igniter.Code.Map, as: CodeMap
  alias VintageNet.Generator

  doctest Generator

  describe inspect(&Generator.add_regulatory_domain/2) do
    test "adds regulatory domain to the config" do
      assert {:ok, igniter, _} =
               test_project()
               |> Generator.add_regulatory_domain("US")
               |> assert_creates("config/target.exs", """
               import Config
               config :vintage_net, regulatory_domain: "US"
               """)
               |> apply_igniter()

      igniter
      |> Generator.add_regulatory_domain("US")
      |> assert_unchanged()
    end
  end

  describe inspect(&Generator.configure_interface/5) do
    test "adds interface to the config" do
      # Increments num in config
      update = fn zipper ->
        CodeMap.set_map_key(zipper, :num, 1, fn zipper ->
          case CodeCommon.expand_literal(zipper) do
            {:ok, num} ->
              {:ok, CodeCommon.replace_code(zipper, num + 1)}

            :error ->
              :error
          end
        end)
      end

      assert {:ok, igniter, _} =
               test_project()
               |> Generator.configure_interface("wlan0", VintageNetWiFi, [num: 1], update)
               |> assert_creates("config/target.exs", """
               import Config
               config :vintage_net, interfaces: [{"wlan0", %{type: VintageNetWiFi, num: 1}}]
               """)
               |> apply_igniter()

      igniter
      |> Generator.configure_interface("wlan0", VintageNetWiFi, [num: 1], update)
      |> assert_has_patch("config/target.exs", """
      1 1   |import Config
      2   - |config :vintage_net, interfaces: [{"wlan0", %{type: VintageNetWiFi, num: 1}}]
        2 + |config :vintage_net, interfaces: [{"wlan0", %{type: VintageNetWiFi, num: 2}}]
      """)
    end
  end
end
