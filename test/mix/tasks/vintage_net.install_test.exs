# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.VintageNet.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  alias Mix.Tasks.VintageNet.Install

  @nerves_new_config """
  import Config

  # Configure the network using vintage_net
  #
  # Update regulatory_domain to your 2-letter country code E.g., "US"
  #
  # See https://github.com/nerves-networking/vintage_net for more information
  config :vintage_net,
    regulatory_domain: "00",
    config: [
      {"usb0", %{type: VintageNetDirect}},
      {"eth0",
       %{
         type: VintageNetEthernet,
         ipv4: %{method: :dhcp}
       }},
      {"wlan0", %{type: VintageNetWiFi}}
    ]
  """

  defp nerves_project(target_exs \\ "import Config\n") do
    test_project(files: %{"config/target.exs" => target_exs})
  end

  defp target_exs(igniter) do
    igniter.rewrite |> Rewrite.source!("config/target.exs") |> Rewrite.Source.get(:content)
  end

  defp install(igniter, argv \\ []) do
    Igniter.compose_task(igniter, "vintage_net.install", argv)
  end

  test "adds the base config to config/target.exs in Nerves projects" do
    nerves_project()
    |> install()
    |> assert_has_patch("config/target.exs", """
    + |config :vintage_net, config: []
    """)
    |> assert_unchanged("config/config.exs")
    |> then(&assert &1.notices == [])
  end

  test "leaves the regulatory domain to vintage_net_wifi.install" do
    igniter = nerves_project() |> install()

    refute target_exs(igniter) =~ "regulatory_domain"
    refute Enum.any?(igniter.notices, &(&1 =~ "regulatory"))

    info = Install.info([], nil)
    assert info.schema == []
  end

  test "falls back to config/config.exs with a notice" do
    igniter =
      test_project()
      |> install()
      |> assert_creates("config/config.exs", """
      import Config
      config :vintage_net, config: []
      """)
      |> refute_creates("config/target.exs")
      |> assert_has_notice(&(&1 =~ "config/target.exs was not found"))

    assert Enum.count(igniter.notices) == 1
  end

  test "is idempotent" do
    nerves_project()
    |> install()
    |> apply_igniter!()
    |> install()
    |> assert_unchanged()

    test_project()
    |> install()
    |> apply_igniter!()
    |> install()
    |> assert_unchanged()
  end

  test "keeps existing config" do
    igniter = nerves_project(@nerves_new_config) |> install() |> assert_unchanged()

    assert igniter.notices == []
  end

  test "adds the interface list when only the regulatory domain is configured" do
    igniter =
      nerves_project("""
      import Config

      config :vintage_net, regulatory_domain: "SE"
      """)
      |> install()
      |> assert_has_patch("config/target.exs", """
      - |config :vintage_net, regulatory_domain: "SE"
      + |config :vintage_net, regulatory_domain: "SE", config: []
      """)

    assert igniter.notices == []
  end

  test "keeps an interface list that has no regulatory domain as it is" do
    igniter =
      nerves_project("""
      import Config

      config :vintage_net,
        config: [
          {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}}
        ]
      """)
      |> install()
      |> assert_unchanged()

    assert igniter.notices == []
  end

  test "uses an existing config/config.exs when there's no config/target.exs" do
    test_project(
      files: %{"config/config.exs" => "import Config\n\nconfig :logger, level: :info\n"}
    )
    |> install()
    |> assert_has_patch("config/config.exs", """
    + |config :vintage_net, config: []
    """)
    |> refute_creates("config/target.exs")
  end

  describe "restricting the dependency to the project's targets" do
    defp targets_mix_exs(deps) do
      """
      defmodule Test.MixProject do
        use Mix.Project

        @app :test
        @device_targets [:rpi4, :rpi5]
        @other_targets [:bbb]

        def project do
          [app: @app, version: "0.1.0", deps: deps()]
        end

        defp deps do
          [
            {:nerves, "~> 2.0", runtime: false},
            #{Enum.join(deps, ",\n      ")}
          ]
        end
      end
      """
    end

    defp targets_install(deps) do
      test_project(
        files: %{"mix.exs" => targets_mix_exs(deps), "config/target.exs" => "import Config\n"}
      )
      |> Igniter.compose_task("vintage_net.install", [])
    end

    defp targets_mix_exs_after(igniter) do
      igniter.rewrite |> Rewrite.source!("mix.exs") |> Rewrite.Source.get(:content)
    end

    test "uses the first targets attribute that another dependency uses" do
      igniter =
        targets_install([
          ~s|{:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4}|,
          ~s|{:nerves_pack, "~> 0.7", targets: @device_targets}|,
          ~s|{:other, "~> 1.0", targets: @other_targets}|,
          ~s|{:vintage_net, "~> 1.0"}|
        ])

      assert targets_mix_exs_after(igniter) =~
               ~s|{:vintage_net, "~> 1.0", targets: @device_targets}|

      # Running it again changes nothing
      igniter
      |> apply_igniter!()
      |> Igniter.compose_task("vintage_net.install", [])
      |> assert_unchanged("mix.exs")
    end

    test "works for dependencies that only have options" do
      igniter =
        targets_install([
          ~s|{:nerves_pack, "~> 0.7", targets: @device_targets}|,
          ~s|{:vintage_net, path: "../vintage_net"}|
        ])

      assert targets_mix_exs_after(igniter) =~
               ~s|{:vintage_net, path: "../vintage_net", targets: @device_targets}|
    end

    test "keeps the targets that the dependency already has" do
      targets_install([
        ~s|{:nerves_pack, "~> 0.7", targets: @device_targets}|,
        ~s|{:vintage_net, "~> 1.0", targets: [:rpi0]}|
      ])
      |> assert_unchanged("mix.exs")
    end

    test "does nothing when no dependency uses a targets attribute" do
      targets_install([
        ~s|{:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4}|,
        ~s|{:vintage_net, "~> 1.0"}|
      ])
      |> assert_unchanged("mix.exs")
    end

    test "falls back to @all_targets when it's defined but not used by a dependency" do
      mix_exs = """
      defmodule Test.MixProject do
        use Mix.Project

        @all_targets [:rpi4, :rpi5]

        def project do
          [app: :test, version: "0.1.0", deps: deps()]
        end

        defp deps do
          [
            {:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4},
            {:vintage_net, "~> 1.0"}
          ]
        end
      end
      """

      igniter =
        test_project(files: %{"mix.exs" => mix_exs, "config/target.exs" => "import Config\n"})
        |> Igniter.compose_task("vintage_net.install", [])

      assert targets_mix_exs_after(igniter) =~ ~s|{:vintage_net, "~> 1.0", targets: @all_targets}|
    end

    test "does nothing when the dependency isn't in mix.exs" do
      targets_install([~s|{:nerves_pack, "~> 0.7", targets: @device_targets}|])
      |> assert_unchanged("mix.exs")
    end
  end

  describe "starting early" do
    test "adds :vintage_net to Nerves' application_sort init list" do
      target_exs = """
      import Config

      config :nerves, application_sort: [init: [:nerves_runtime]]
      """

      igniter =
        test_project(files: %{"config/target.exs" => target_exs})
        |> Igniter.compose_task("vintage_net.install", [])

      assert igniter.rewrite
             |> Rewrite.source!("config/target.exs")
             |> Rewrite.Source.get(:content) =~
               "config :nerves, application_sort: [init: [:nerves_runtime, :vintage_net]]"

      igniter
      |> apply_igniter!()
      |> Igniter.compose_task("vintage_net.install", [])
      |> assert_unchanged()
    end

    test "leaves a list with :nerves_pack alone and doesn't create one" do
      target_exs = """
      import Config

      config :shoehorn, init: [:nerves_runtime, :nerves_pack]
      """

      igniter =
        test_project(files: %{"config/target.exs" => target_exs})
        |> Igniter.compose_task("vintage_net.install", [])

      content =
        igniter.rewrite |> Rewrite.source!("config/target.exs") |> Rewrite.Source.get(:content)

      assert content =~ "config :shoehorn, init: [:nerves_runtime, :nerves_pack]"
      refute content =~ "application_sort"
    end
  end
end
