# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.VintageNet.Install.Docs do
  @moduledoc false

  @spec short_doc() :: String.t()
  def short_doc() do
    "Installs vintage_net in your Nerves project."
  end

  @spec example() :: String.t()
  def example() do
    "mix igniter.install vintage_net"
  end

  @spec long_doc() :: String.t()
  def long_doc() do
    """
    #{short_doc()}

    This adds VintageNet's base configuration to `config/target.exs`:

    ```elixir
    config :vintage_net, config: []
    ```

    Network interfaces are added to the `:config` list by the installers for
    the VintageNet technologies. For example, `vintage_net_ethernet`,
    `vintage_net_wifi` and `vintage_net_direct`. Configuration that's already
    in the project is kept.

    The regulatory domain only applies to WiFi, so it's set by
    `mix vintage_net_wifi.install` and its `--regulatory-domain` option.

    If the project doesn't have a `config/target.exs`, the configuration is
    written to `config/config.exs`.

    ## Example

    ```bash
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.VintageNet.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    alias VintageNet.Generator

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :vintage_net,
        example: __MODULE__.Docs.example(),
        schema: [],
        defaults: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Generator.restrict_dep_to_targets(:vintage_net)
      |> Generator.add_base_config()
      |> Generator.start_early(:vintage_net)
      |> maybe_add_not_nerves_notice()
    end

    defp maybe_add_not_nerves_notice(igniter) do
      if Generator.config_file(igniter) == "target.exs" do
        igniter
      else
        Igniter.add_notice(igniter, """
        vintage_net: config/target.exs was not found, so VintageNet's
        configuration was added to config/config.exs.

        VintageNet is meant for Nerves devices and these defaults assume a
        Nerves project. If this project also runs on your computer, move the
        configuration to where it only applies to the device.
        """)
      end
    end
  end
else
  defmodule Mix.Tasks.VintageNet.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'vintage_net.install' requires igniter. Please install igniter and try again.

      For more information, see: https://igniter.hexdocs.pm/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
