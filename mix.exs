defmodule VintageNet.MixProject do
  use Mix.Project

  @version "0.2.4"

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
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs(),
      package: package(),
      description: description()
    ]
  end

  def application do
    [
      # The bin_* variables are paths to programs. Set to absolute paths to pin.
      # Program names are found at application start and converted to absolute.
      env: [
        config: [],
        tmpdir: "/tmp/vintage_net",
        to_elixir_socket: "comms",
        bin_ifup: "ifup",
        bin_ifdown: "ifdown",
        bin_ifconfig: "ifconfig",
        bin_chat: "chat",
        bin_pppd: "pppd",
        bin_mknod: "mknod",
        bin_killall: "killall",
        bin_wpa_supplicant: "/usr/sbin/wpa_supplicant",
        bin_ip: "ip",
        bin_udhcpd: "udhcpd",
        bin_dnsd: "dnsd",
        path: "/usr/sbin:/usr/bin:/sbin:/bin",
        udhcpc_handler: VintageNet.Interface.Udhcpc,
        resolvconf: "/etc/resolv.conf",
        persistence: VintageNet.Persistence.FlatFile,
        persistence_dir: "/root/vintage_net",
        persistence_secret: "obfuscate_things",
        internet_host: {1, 1, 1, 1},
        regulatory_domain: "00"
      ],
      extra_applications: [:logger],
      mod: {VintageNet.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "Alternative network management for Nerves"
  end

  defp package do
    %{
      files: [
        "lib",
        "test",
        "mix.exs",
        "Makefile",
        "README.md",
        "src/*.[ch]",
        "LICENSE",
        "CHANGELOG.md"
      ],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/nerves-networking/vintage_net"}
    }
  end

  defp deps do
    [
      {:elixir_make, "~> 0.5", runtime: false},
      {:ex_doc, "~> 0.19", only: :docs, runtime: false},
      {:mix_test_watch, "~> 0.5", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.8", only: :test, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev, :test], runtime: false},
      {:muontrap, "~> 0.4.1"},
      {:gen_state_machine, "~> 2.0.0"},
      {:busybox, "~> 0.1", optional: true}
    ]
  end

  defp dialyzer() do
    [
      flags: [:race_conditions, :unmatched_returns, :error_handling],
      plt_add_apps: [:busybox]
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: "https://github.com/nerves-networking/vintage_net"
    ]
  end
end
