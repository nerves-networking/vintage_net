defmodule VintageNet.MixProject do
  use Mix.Project

  @version "0.8.0"
  @source_url "https://github.com/nerves-networking/vintage_net"

  def project do
    [
      app: :vintage_net,
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      start_permanent: Mix.env() == :prod,
      build_embedded: true,
      compilers: [:elixir_make | Mix.compilers()],
      make_targets: ["all"],
      make_clean: ["clean"],
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
      # The bin_* variables are paths to programs. Set to absolute paths to pin.
      # Program names are found at application start and converted to absolute.
      env: [
        config: [],
        max_interface_count: 8,
        tmpdir: "/tmp/vintage_net",
        to_elixir_socket: "comms",
        bin_dnsd: "dnsd",
        bin_ifconfig: "ifconfig",
        bin_chat: "chat",
        bin_pppd: "pppd",
        bin_mknod: "mknod",
        bin_killall: "killall",
        bin_wpa_supplicant: "/usr/sbin/wpa_supplicant",
        bin_ip: "ip",
        bin_udhcpc: "udhcpc",
        bin_udhcpd: "udhcpd",
        bin_brctl: "brctl",
        path: "/usr/sbin:/usr/bin:/sbin:/bin",
        udhcpc_handler: VintageNet.Interface.Udhcpc,
        udhcpd_handler: VintageNet.Interface.Udhcpd,
        resolvconf: "/etc/resolv.conf",
        persistence: VintageNet.Persistence.FlatFile,
        persistence_dir: "/root/vintage_net",
        persistence_secret: "obfuscate_things",
        internet_host: {1, 1, 1, 1},
        regulatory_domain: "00",
        # Contain processes in cgroups by setting to:
        #   [cgroup_base: "vintage_net", cgroup_controllers: ["cpu"]]
        muontrap_options: []
      ],
      extra_applications: [:logger],
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
        "test",
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
      {:elixir_make, "~> 0.6", runtime: false},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false},
      {:excoveralls, "~> 0.13", only: :test, runtime: false},
      {:dialyxir, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:muontrap, "~> 0.5.1 or ~> 0.6.0"},
      {:gen_state_machine, "~> 2.0.0 or ~> 2.1.0"},
      {:busybox, "~> 0.1.5", optional: true},
      {:credo, "~> 1.2", only: :test, runtime: false}
    ]
  end

  defp dialyzer() do
    [
      flags: [:race_conditions, :unmatched_returns, :error_handling, :underspecs],
      plt_add_apps: [:busybox],
      ignore_warnings: ".dialyzer_ignore.exs",
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
