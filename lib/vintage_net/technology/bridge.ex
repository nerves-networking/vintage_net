defmodule VintageNetBridge do
  @moduledoc """
  Configurations for this technology are maps with a `:type` field set to
  `VintageNetBridge`. The following additional fields are supported:

  * `:vintage_net_bridge` - Bridge options

  Here's a typical configuration for setting up a bridge between ethernet and wifi

  ```elixir
  %{
    type: VintageNetBridge,
    vintage_net_bridge: %{
      vintage_net_bridge: %{
      interfaces: ["eth0", "wlan0"],
    }
  }
  """

  @behaviour VintageNet.Technology

  alias VintageNet.Interface.RawConfig

  @impl true
  def normalize(config), do: config

  @impl true
  def to_raw_config(ifname, config, opts) do
    normalized_config = normalize(config)
    bridge_config = normalized_config[:vintage_net_bridge]
    brctl = Keyword.fetch!(opts, :bin_brctl)

    up_cmds = [
      {:run, brctl, ["addbr", ifname]}
    ]

    down_cmds = [
      {:run, brctl, ["delbr", ifname]}
    ]

    base = %RawConfig{
      ifname: ifname,
      type: __MODULE__,
      source_config: normalized_config,
      up_cmds: up_cmds,
      down_cmds: down_cmds,
      require_interface: false
    }

    Enum.reduce(bridge_config, base, fn
      # TODO(Connor) we may need a genserver here to listen for the interfaces
      # in this list to populate, and add them to the brige, maybe via a :ioctl 
      {:interfaces, interfaces}, raw_config when is_list(interfaces) ->
        addifs =
          Enum.map(interfaces, fn addif ->
            {:run, brctl, ["addif", raw_config.ifname, addif]}
          end)

        %{raw_config | up_cmds: raw_config.up_cmds ++ addifs}

      {:forward_delay, value}, raw_config ->
        up_cmd = {:run, brctl, ["setfd", raw_config.ifname, value]}
        %{raw_config | up_cmds: raw_config.up_cmds ++ [up_cmd]}

      {:priority, value}, raw_config ->
        up_cmd = {:run, brctl, ["setbridgeprio", raw_config.ifname, value]}
        %{raw_config | up_cmds: raw_config.up_cmds ++ [up_cmd]}

      {:hello_time, value}, raw_config ->
        up_cmd = {:run, brctl, ["sethello", raw_config.ifname, value]}
        %{raw_config | up_cmds: raw_config.up_cmds ++ [up_cmd]}

      {:max_age, value}, raw_config ->
        up_cmd = {:run, brctl, ["setmaxage", raw_config.ifname, value]}
        %{raw_config | up_cmds: raw_config.up_cmds ++ [up_cmd]}

      {:path_cost, value}, raw_config ->
        up_cmd = {:run, brctl, ["setpathcost", raw_config.ifname, value]}
        %{raw_config | up_cmds: raw_config.up_cmds ++ [up_cmd]}

      {:path_priority, value}, raw_config ->
        up_cmd = {:run, brctl, ["setportprio", raw_config.ifname, value]}
        %{raw_config | up_cmds: raw_config.up_cmds ++ [up_cmd]}

      {:hairpin, {port, value}}, raw_config when is_integer(port) and is_boolean(value) ->
        up_cmd = {:run, brctl, ["hairpin", raw_config.ifname, port, bool_to_yn(value)]}
        %{raw_config | up_cmds: raw_config.up_cmds ++ [up_cmd]}

      {:stp, value}, raw_config when is_boolean(value) ->
        up_cmd = {:run, brctl, ["stp", raw_config.ifname, bool_to_yn(value)]}
        %{raw_config | up_cmds: raw_config.up_cmds ++ [up_cmd]}
    end)
  end

  @impl true
  # TODO(connor) add support for modifying the bridge
  # in real time
  def ioctl(_ifname, _command, _args) do
    {:error, :unsupported}
  end

  @impl true
  # TODO(connor) check for brctl utility
  def check_system(_opts), do: :ok

  defp bool_to_yn(true), do: "yes"
  defp bool_to_yn(false), do: "no"
end
