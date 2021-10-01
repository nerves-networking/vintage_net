defmodule VintageNet.MixProject do
  use Mix.Project

  @version "0.11.1"
  @source_url "https://github.com/nerves-networking/vintage_net"

  def project do
    [
      app: :vintage_net,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      start_permanent: Mix.env() == :prod,
      build_embedded: true,
      compilers: [:elixir_make | Mix.compilers()],
      make_targets: ["all"],
      make_clean: ["mix_clean"],
      make_error_message: "",
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs(),
      package: package(),
      description: description(),
      aliases: [compile: [&check_deps/1, "compile"]],
      preferred_cli_env: %{
        docs: :docs,
        "hex.publish": :docs,
        "hex.build": :docs,
        credo: :test,
        "coveralls.circle": :test
      }
    ]
  end

  def application do
    [
      env: [
        config: [],
        max_interface_count: 8,
        tmpdir: "/tmp/vintage_net",
        path: "/usr/sbin:/usr/bin:/sbin:/bin",
        udhcpc_handler: VintageNet.Interface.Udhcpc,
        udhcpd_handler: VintageNet.Interface.Udhcpd,
        resolvconf: "/etc/resolv.conf",
        persistence: VintageNet.Persistence.FlatFile,
        persistence_dir: "/root/vintage_net",
        persistence_secret: "obfuscate_things",
        # List of reliable hosts used to check Internet connectivity
        # Use IP addresses and port numbers here rather than names.
        internet_host_list: [
          # Cloudflare DNS over TCP
          {{1, 1, 1, 1}, 53},
          # Google public DNS over TCP
          {{8, 8, 8, 8}, 53},
          # OpenDNS
          {{208, 67, 222, 222}, 53},
          # Quad9
          {{9, 9, 9, 9}, 53},
          # Neustar
          {{156, 154, 70, 5}, 53}
        ],
        regulatory_domain: "00",
        # Contain processes in cgroups by setting to:
        #   [cgroup_base: "vintage_net", cgroup_controllers: ["cpu"]]
        muontrap_options: [],
        power_managers: [],
        route_metric_fun: &VintageNet.Route.DefaultMetric.compute_metric/2
      ],
      extra_applications: [:logger, :crypto],
      mod: {VintageNet.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "Network configuration and management for Nerves"
  end

  defp package do
    %{
      files: [
        "lib",
        "mix.exs",
        "Makefile",
        "README.md",
        "docs/cookbook.md",
        "src/*.[ch]",
        "src/test-c99.sh",
        "LICENSE",
        "CHANGELOG.md"
      ],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    }
  end

  defp deps do
    [
      # Runtime dependencies
      {:beam_notify, "~> 0.2.0"},
      {:gen_state_machine, "~> 2.0.0 or ~> 2.1.0 or ~> 3.0.0"},
      {:muontrap, "~> 0.5.1 or ~> 0.6.0"},
      # Build dependencies
      {:credo, "~> 1.2", only: :test, runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:elixir_make, "~> 0.6", runtime: false},
      {:excoveralls, "~> 0.13", only: :test, runtime: false},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false}
    ]
  end

  defp dialyzer() do
    [
      flags: [:race_conditions, :unmatched_returns, :error_handling, :underspecs],
      list_unused_filters: true
    ]
  end

  defp docs do
    [
      extras: ["README.md", "docs/cookbook.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp check_deps(_) do
    for bad_dep <- [:nerves_init_gadget, :nerves_network] do
      Mix.Project.in_project(bad_dep, "/tmp", fn module ->
        if module do
          Mix.raise("""
          vintage_net is incompatible with #{inspect(bad_dep)}.

          Please remove #{inspect(bad_dep)} from your project's mix dependencies. See
          https://hexdocs.pm/vintage_net/readme.html#installation for help.
          """)
        end
      end)
    end
  end
end
