defmodule VintageNet.MixProject do
  use Mix.Project

  def project do
    [
      app: :vintage_net,
      version: "0.1.0",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      docs: [extras: ["README.md"]],
      package: package(),
      description: description()
    ]
  end

  def application do
    [
      env: [
        config: [],
        tmpdir: "/tmp/vintage_net",
        bin_ifup: "/sbin/ifup",
        bin_ifdown: "/sbin/ifdown",
        bin_chat: "/usr/sbin/chat",
        bin_pppd: "/usr/sbin/pppd",
        bin_mknod: "/bin/mknod",
        bin_killall: "/usr/bin/killall",
        bin_wpa_supplicant: "/usr/sbin/wpa_supplicant"
      ],
      extra_applications: [:logger],
      mod: {VintageNet.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "Manage network connections the way your parents did"
  end

  defp package do
    %{
      files: [
        "lib",
        "test",
        "mix.exs",
        "README.md",
        "LICENSE",
        "CHANGELOG.md",
        "docs/*.md"
      ],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/nerves-project/vintage_networking"}
    }
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 0.5", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer() do
    [
      flags: [:unmatched_returns, :error_handling, :race_conditions, :underspecs]
    ]
  end
end
