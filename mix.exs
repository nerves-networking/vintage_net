defmodule VintageNet.MixProject do
  use Mix.Project

  def project do
    [
      app: :vintage_net,
      version: "0.2.0",
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
      docs: [extras: ["README.md"], main: "readme"],
      package: package(),
      description: description()
    ]
  end

  def application do
    [
      env: [
        config: [],
        tmpdir: "/tmp/vintage_net",
        to_elixir_socket: "comms",
        bin_ifup: "/sbin/ifup",
        bin_ifdown: "/sbin/ifdown",
        bin_chat: "/usr/sbin/chat",
        bin_pppd: "/usr/sbin/pppd",
        bin_mknod: "/bin/mknod",
        bin_killall: "/usr/bin/killall",
        bin_wpa_supplicant: "/usr/sbin/wpa_supplicant",
        bin_wpa_cli: "/usr/sbin/wpa_cli",
        bin_ip: "/sbin/ip",
        bin_udhcpd: "/usr/sbin/udhcpd",
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
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:mix_test_watch, "~> 0.5", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.8", only: :test, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: :dev, runtime: false},
      {:muontrap, "~> 0.4.1"},
      {:gen_state_machine, "~> 2.0.0"}
    ]
  end

  defp dialyzer() do
    [
      flags: [:race_conditions, :unmatched_returns, :error_handling]
    ]
  end
end
