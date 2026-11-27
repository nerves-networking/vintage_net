# SPDX-FileCopyrightText: 2025 Jonatan Männchen
# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.GeneratorTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  alias Igniter.Code.Common, as: CodeCommon
  alias Igniter.Code.Map, as: CodeMap
  alias VintageNet.Generator

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

  config :mdns_lite, hosts: [:hostname, "nerves"]
  """

  defp nerves_project(target_exs \\ "import Config\n") do
    test_project(files: %{"config/target.exs" => target_exs})
  end

  defp content(igniter, path) do
    igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)
  end

  describe "config_file/1" do
    test "is target.exs for Nerves projects" do
      assert Generator.config_file(nerves_project()) == "target.exs"
    end

    test "is config.exs when there's no target.exs" do
      assert Generator.config_file(test_project()) == "config.exs"
    end
  end

  describe "add_base_config/2" do
    test "adds an empty interface list and no regulatory domain" do
      igniter = nerves_project() |> Generator.add_base_config() |> apply_igniter!()

      assert content(igniter, "config/target.exs") == """
             import Config
             config :vintage_net, config: []
             """

      igniter |> Generator.add_base_config() |> assert_unchanged()
    end

    test "writes a regulatory domain when given one" do
      nerves_project()
      |> Generator.add_base_config(regulatory_domain: "SE")
      |> assert_has_patch("config/target.exs", """
      + |config :vintage_net, regulatory_domain: "SE", config: []
      """)
    end

    test "falls back to config.exs" do
      test_project()
      |> Generator.add_base_config()
      |> assert_creates("config/config.exs", """
      import Config
      config :vintage_net, config: []
      """)
      |> refute_creates("config/target.exs")
    end

    test "keeps existing configuration" do
      nerves_project(@nerves_new_config)
      |> Generator.add_base_config(regulatory_domain: "SE")
      |> assert_unchanged()
    end

    test "leaves files byte-identical when nothing needs to change" do
      # Each of these fits on fewer lines than it's written on
      configs = [
        """
        import Config

        config :vintage_net,
          regulatory_domain: "US",
          config: [
            {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}}
          ]
        """,
        """
        import Config

        config :vintage_net,
          regulatory_domain: "US",
          config: [
            {"eth0",
             %{
               type: VintageNetEthernet,
               ipv4: %{method: :dhcp}
             }},
            {"wlan0", %{type: VintageNetWiFi}}
          ]

        # Trailing comment
        """,
        """
        import Config

        config :vintage_net, :regulatory_domain, "US"

        config :vintage_net, :config, [
          {"usb0", %{type: VintageNetDirect}}
        ]
        """
      ]

      for config <- configs do
        igniter = nerves_project(config) |> Generator.add_base_config()

        assert content(igniter, "config/target.exs") == config
        assert_unchanged(igniter)

        igniter =
          nerves_project(config)
          |> Generator.add_interface("eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}})
          |> Generator.add_interface("usb0", %{type: VintageNetDirect})
          |> Generator.add_interface("wlan0", %{type: VintageNetWiFi})

        # Only what was missing is added
        assert length(String.split(content(igniter, "config/target.exs"), ~s|{"|)) == 4

        igniter = igniter |> apply_igniter!()
        applied = content(igniter, "config/target.exs")

        igniter =
          igniter
          |> Generator.add_interface("eth0", %{type: VintageNetEthernet})
          |> Generator.add_interface("usb0", %{type: VintageNetDirect})
          |> Generator.add_interface("wlan0", %{type: VintageNetWiFi})
          |> Generator.add_base_config()
          |> Generator.add_regulatory_domain("SE")

        assert content(igniter, "config/target.exs") == applied
        assert_unchanged(igniter)
      end
    end

    test "adds what's missing" do
      nerves_project("""
      import Config

      config :vintage_net, regulatory_domain: "US"
      """)
      |> Generator.add_base_config()
      |> assert_has_patch("config/target.exs", """
      - |config :vintage_net, regulatory_domain: "US"
      + |config :vintage_net, regulatory_domain: "US", config: []
      """)

      # A regulatory domain isn't missing. It's only for WiFi.
      nerves_project("""
      import Config

      config :vintage_net, config: [{"eth0", %{type: VintageNetEthernet}}]
      """)
      |> Generator.add_base_config()
      |> assert_unchanged()
    end
  end

  describe "add_regulatory_domain/3" do
    test "adds regulatory domain to the config" do
      igniter =
        nerves_project()
        |> Generator.add_regulatory_domain("US")
        |> assert_has_patch("config/target.exs", """
        + |config :vintage_net, regulatory_domain: "US"
        """)
        |> apply_igniter!()

      igniter
      |> Generator.add_regulatory_domain("US")
      |> assert_unchanged()
    end

    test "doesn't replace an existing regulatory domain by default" do
      nerves_project(@nerves_new_config)
      |> Generator.add_regulatory_domain("US")
      |> assert_unchanged()
    end

    test "goes before the interface list when added to existing config" do
      nerves_project("""
      import Config

      config :vintage_net, config: [{"eth0", %{type: VintageNetEthernet}}]
      """)
      |> Generator.add_regulatory_domain("US")
      |> assert_has_patch("config/target.exs", """
      - |config :vintage_net, config: [{"eth0", %{type: VintageNetEthernet}}]
      + |config :vintage_net, regulatory_domain: "US", config: [{"eth0", %{type: VintageNetEthernet}}]
      """)

      igniter =
        nerves_project("""
        import Config

        # Networking
        config :vintage_net,
          # The interfaces
          config: [
            {"usb0", %{type: VintageNetDirect}},
            {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}}
          ],
          additional_name_servers: [{1, 1, 1, 1}]

        config :logger, level: :info
        """)
        |> Generator.add_regulatory_domain("00")
        |> apply_igniter!()

      assert content(igniter, "config/target.exs") == """
             import Config

             # Networking
             config :vintage_net,
               regulatory_domain: "00",
               # The interfaces
               config: [
                 {"usb0", %{type: VintageNetDirect}},
                 {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}}
               ],
               additional_name_servers: [{1, 1, 1, 1}]

             config :logger, level: :info
             """

      igniter |> Generator.add_regulatory_domain("00") |> assert_unchanged()
    end

    test "is added the same no matter if it's before or after the interfaces" do
      before =
        nerves_project()
        |> Generator.add_regulatory_domain("00")
        |> Generator.add_interface("wlan0", %{type: VintageNetWiFi})
        |> apply_igniter!()

      after_ =
        nerves_project()
        |> Generator.add_interface("wlan0", %{type: VintageNetWiFi})
        |> Generator.add_regulatory_domain("00")
        |> apply_igniter!()

      assert content(before, "config/target.exs") == """
             import Config
             config :vintage_net, regulatory_domain: "00", config: [{"wlan0", %{type: VintageNetWiFi}}]
             """

      assert content(after_, "config/target.exs") == content(before, "config/target.exs")
    end

    test "keeps the 3-argument config form" do
      nerves_project("""
      import Config

      config :vintage_net, :config, [{"eth0", %{type: VintageNetEthernet}}]
      """)
      |> Generator.add_regulatory_domain("US")
      |> then(fn igniter ->
        assert content(igniter, "config/target.exs") =~ ~s|regulatory_domain: "US"|
        igniter
      end)
      |> apply_igniter!()
      |> Generator.add_regulatory_domain("US")
      |> assert_unchanged()
    end

    test "replaces an existing regulatory domain when asked" do
      nerves_project(@nerves_new_config)
      |> Generator.add_regulatory_domain("US", overwrite?: true)
      |> assert_has_patch("config/target.exs", """
      - |  regulatory_domain: "00",
      + |  regulatory_domain: "US",
      """)
    end
  end

  describe "add_interface/3" do
    test "creates the base config when missing" do
      igniter =
        nerves_project()
        |> Generator.add_interface("eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}})
        |> apply_igniter!()

      assert content(igniter, "config/target.exs") == """
             import Config
             config :vintage_net, config: [{"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}}]
             """
    end

    test "is idempotent" do
      add = fn igniter ->
        igniter
        |> Generator.add_interface("eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}})
        |> Generator.add_interface("wlan0", %{type: VintageNetWiFi})
      end

      igniter = nerves_project() |> add.() |> apply_igniter!()

      igniter |> add.() |> assert_unchanged()
    end

    test "adds multiple interfaces in order" do
      igniter =
        nerves_project()
        |> Generator.add_interface("usb0", %{type: VintageNetDirect})
        |> Generator.add_interface("eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}})
        |> Generator.add_interface("wlan0", %{type: VintageNetWiFi})
        |> apply_igniter!()

      assert content(igniter, "config/target.exs") == """
             import Config

             config :vintage_net,
               config: [
                 {"usb0", %{type: VintageNetDirect}},
                 {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}},
                 {"wlan0", %{type: VintageNetWiFi}}
               ]
             """
    end

    test "adds to the interface list that vintage_net.install made" do
      nerves_project()
      |> Igniter.compose_task("vintage_net.install", [])
      |> apply_igniter!()
      |> Generator.add_interface("wlan0", %{type: VintageNetWiFi})
      |> assert_has_patch("config/target.exs", """
      - |config :vintage_net, config: []
      + |config :vintage_net, config: [{"wlan0", %{type: VintageNetWiFi}}]
      """)
    end

    test "falls back to config.exs" do
      test_project()
      |> Generator.add_interface("eth0", %{type: VintageNetEthernet})
      |> assert_creates("config/config.exs", """
      import Config
      config :vintage_net, config: [{"eth0", %{type: VintageNetEthernet}}]
      """)
      |> refute_creates("config/target.exs")
    end

    test "doesn't change mix nerves.new projects" do
      nerves_project(@nerves_new_config)
      |> Generator.add_interface("usb0", %{type: VintageNetDirect})
      |> Generator.add_interface("eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}})
      |> Generator.add_interface("wlan0", %{type: VintageNetWiFi})
      |> assert_unchanged()
    end

    test "never replaces an interface that's already configured" do
      nerves_project("""
      import Config

      config :vintage_net,
        regulatory_domain: "US",
        config: [
          {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :static, address: "192.168.1.5"}}}
        ]
      """)
      |> Generator.add_interface("eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}})
      |> assert_unchanged()
    end

    test "appends to existing interfaces and keeps them as is" do
      igniter =
        nerves_project("""
        import Config

        # Networking
        config :vintage_net,
          regulatory_domain: "US",
          config: [
            # Wired
            {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :static, address: "192.168.1.5"}}},
            {"usb0", %{type: VintageNetDirect}}
          ]
        """)
        |> Generator.add_interface("eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}})
        |> Generator.add_interface("wlan0", %{type: VintageNetWiFi})
        |> apply_igniter!()

      assert content(igniter, "config/target.exs") == """
             import Config

             # Networking
             config :vintage_net,
               regulatory_domain: "US",
               config: [
                 # Wired
                 {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :static, address: "192.168.1.5"}}},
                 {"usb0", %{type: VintageNetDirect}},
                 {"wlan0", %{type: VintageNetWiFi}}
               ]
             """
    end

    test "adds the interface list when only other keys are configured" do
      nerves_project("""
      import Config

      config :vintage_net, regulatory_domain: "US"
      """)
      |> Generator.add_interface("wlan0", %{type: VintageNetWiFi})
      |> assert_has_patch("config/target.exs", """
      - |config :vintage_net, regulatory_domain: "US"
      + |config :vintage_net, regulatory_domain: "US", config: [{"wlan0", %{type: VintageNetWiFi}}]
      """)
    end

    test "works with the three argument form of config" do
      nerves_project("""
      import Config

      config :vintage_net, :regulatory_domain, "US"
      config :vintage_net, :config, [{"eth0", %{type: VintageNetEthernet}}]
      """)
      |> Generator.add_interface("wlan0", %{type: VintageNetWiFi})
      |> assert_has_patch("config/target.exs", """
      + |config :vintage_net, :config, [
      + |  {"eth0", %{type: VintageNetEthernet}},
      + |  {"wlan0", %{type: VintageNetWiFi}}
      + |]
      """)
    end

    test "writes maps with the type first" do
      nerves_project()
      |> Generator.add_interface("eth0", %{
        ipv4: %{method: :static, address: "192.168.1.5", prefix_length: 24},
        dhcpd: %{start: {192, 168, 1, 10}},
        type: VintageNetEthernet
      })
      |> assert_has_patch("config/target.exs", """
      + |    {"eth0",
      + |     %{
      + |       type: VintageNetEthernet,
      + |       dhcpd: %{start: {192, 168, 1, 10}},
      + |       ipv4: %{address: "192.168.1.5", method: :static, prefix_length: 24}
      + |     }}
      """)
    end

    test "writes keyword lists as maps in the order given" do
      nerves_project()
      |> Generator.add_interface("eth0", ipv4: %{method: :dhcp}, type: VintageNetEthernet)
      |> assert_has_patch("config/target.exs", """
      + |config :vintage_net, config: [{"eth0", %{ipv4: %{method: :dhcp}, type: VintageNetEthernet}}]
      """)
    end

    test "writes code" do
      code =
        Sourceror.parse_string!("""
        %{
          type: VintageNetWiFi,
          vintage_net_wifi: %{networks: [%{ssid: System.get_env("SSID")}]}
        }
        """)

      igniter = nerves_project() |> Generator.add_interface("wlan0", {:code, code})

      assert_has_patch(igniter, "config/target.exs", """
      + |       vintage_net_wifi: %{networks: [%{ssid: System.get_env("SSID")}]}
      """)

      igniter
      |> apply_igniter!()
      |> Generator.add_interface("wlan0", {:code, code})
      |> assert_unchanged()
    end

    test "warns when the interface list isn't a list" do
      nerves_project("""
      import Config

      interfaces = [{"eth0", %{type: VintageNetEthernet}}]

      config :vintage_net, regulatory_domain: "US", config: interfaces
      """)
      |> Generator.add_interface("wlan0", %{type: VintageNetWiFi})
      |> assert_unchanged("config/target.exs")
      |> assert_has_warning(&(&1 =~ ~s|{"wlan0", %{type: VintageNetWiFi}}|))
    end
  end

  describe "configure_interface/5" do
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

      igniter =
        nerves_project()
        |> Generator.configure_interface("wlan0", VintageNetWiFi, [num: 1], update)
        |> apply_igniter!()

      assert content(igniter, "config/target.exs") == """
             import Config
             config :vintage_net, config: [{"wlan0", %{type: VintageNetWiFi, num: 1}}]
             """

      igniter
      |> Generator.configure_interface("wlan0", VintageNetWiFi, [num: 1], update)
      |> assert_has_patch("config/target.exs", """
      - |config :vintage_net, config: [{"wlan0", %{type: VintageNetWiFi, num: 1}}]
      + |config :vintage_net, config: [{"wlan0", %{type: VintageNetWiFi, num: 2}}]
      """)
    end

    test "keeps existing interfaces by default" do
      nerves_project(@nerves_new_config)
      |> Generator.configure_interface("wlan0", VintageNetWiFi, ipv4: %{method: :dhcp})
      |> assert_unchanged()
    end
  end

  describe "move_to_interface_config/2" do
    test "moves to the config for an interface" do
      zipper =
        ~s|[{"eth0", %{type: VintageNetEthernet}}, {"wlan0", %{type: VintageNetWiFi}}]|
        |> Sourceror.parse_string!()
        |> Sourceror.Zipper.zip()

      assert {:ok, zipper} = Generator.move_to_interface_config(zipper, "wlan0")
      assert Sourceror.to_string(zipper.node) == "%{type: VintageNetWiFi}"

      assert :error = Generator.move_to_interface_config(zipper, "usb0")
    end
  end
end
