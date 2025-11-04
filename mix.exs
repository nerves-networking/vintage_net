defmodule VintageNet.MixProject do
  use Mix.Project

  @app :vintage_net
  @version "0.13.9"
  @source_url "https://github.com/nerves-networking/#{@app}"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make | Mix.compilers()],
      make_targets: ["all"],
      make_clean: ["mix_clean"],
      make_error_message: make_error_message(Mix.target()),
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs(),
      package: package(),
      description: description(),
      aliases: [compile: [&check_deps/1, "compile"]]
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
        route_metric_fun: {VintageNet.Route.DefaultMetric, :compute_metric, 2}
      ],
      extra_applications: [:logger, :crypto],
      mod: {VintageNet.Application, []}
    ]
  end

  def cli do
    [preferred_envs: %{docs: :docs, "hex.publish": :docs, "hex.build": :docs, credo: :test}]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "Network configuration and management for Nerves"
  end

  defp package do
    %{
      files: [
        "CHANGELOG.md",
        "docs/cookbook.md",
        "lib",
        "LICENSES",
        "mix.exs",
        "Makefile",
        "NOTICE",
        "README.md",
        "REUSE.toml",
        "src/*.[ch]",
        "src/test-c99.sh"
      ],
      licenses: ["Apache-2.0"],
      links: %{
        "Changelog" => "https://hexdocs.pm/#{@app}/changelog.html",
        "GitHub" => @source_url,
        "REUSE Compliance" =>
          "https://api.reuse.software/info/github.com/nerves-networking/#{@app}"
      }
    }
  end

  defp deps do
    [
      # Runtime dependencies
      {:beam_notify, "~> 1.0 or ~> 0.2.0"},
      {:muontrap, "~> 1.0 or ~> 0.5.1 or ~> 0.6.0"},
      {:property_table, "~> 0.2.0 or ~> 0.3.0"},
      # Build dependencies
      {:credo, "~> 1.2", only: :test, runtime: false},
      {:credo_binary_patterns, "~> 0.2.2", only: :test, runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:elixir_make, "~> 0.6", runtime: false},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false}
    ]
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs],
      list_unused_filters: true,
      plt_file: {:no_warn, "_build/plts/dialyzer.plt"}
    ]
  end

  defp docs do
    [
      before_closing_body_tag: &before_closing_body_tag/1,
      extras: ["README.md", "docs/cookbook.md", "CHANGELOG.md"],
      main: "readme",
      logo: "assets/vintage_net-notext.png",
      assets: %{"assets" => "assets"},
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp before_closing_body_tag(:html) do
    """
    <script src="https://cdn.jsdelivr.net/npm/mermaid@8.13.3/dist/mermaid.min.js"></script>
    <script>
    document.addEventListener("DOMContentLoaded", function () {
      mermaid.initialize({ startOnLoad: false });
      let id = 0;
      for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
        const preEl = codeEl.parentElement;
        const graphDefinition = codeEl.textContent;
        const graphEl = document.createElement("div");
        const graphId = "mermaid-graph-" + id++;
        mermaid.render(graphId, graphDefinition, function (svgSource, bindListeners) {
          graphEl.innerHTML = svgSource;
          bindListeners && bindListeners(graphEl);
          preEl.insertAdjacentElement("afterend", graphEl);
          preEl.remove();
        });
      }
    });
    </script>
    """
  end

  defp before_closing_body_tag(_), do: ""

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

  defp make_error_message(:host) do
    """

    Make failed to compile vintage_net when compiling for the host.

    Possible causes:

    1. You didn't mean to compile for host. Check that MIX_TARGET is set.

    2. Your system doesn't have the necessary header files installed. The
       details depend on your package manager. On Debian/Ubuntu systems, run
       `sudo apt install libmnl-dev libnl-genl-3-dev`

    3. Something regressed. Please file an issue at
       https://github.com/nerves-networking/vintage_net.
    """
  end

  defp make_error_message(target) do
    """

    Make failed to compile vintage_net when compiling for the target '#{target}'.

    If you're using an officially maintained Nerves system, please file an issue.

    This is usually due to the following lines not being in the `nerves_defconfig`:

    BR2_PACKAGE_LIBMNL=y
    BR2_PACKAGE_LIBNL=y
    """
  end
end
