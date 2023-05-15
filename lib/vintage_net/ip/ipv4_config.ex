defmodule VintageNet.IP.IPv4Config do
  @moduledoc """
  This is a helper module for VintageNet.Technology implementations that use
  IPv4.

  IPv4 configuration is specified under the `:ipv4` key in the configuration map.
  Fields include:

  * `:method` - `:dhcp`, `:static`, or `:disabled`

  The `:dhcp` method currently has no additional fields.

  The `:static` method uses the following fields:

  * `:address` - the IP address
  * `:prefix_length` - the number of bits in the IP address to use for the subnet (e.g., 24)
  * `:netmask` - either this or `prefix_length` is used to determine the subnet. If you
    have a choice, use `prefix_length`
  * `:gateway` - the default gateway for this interface (optional)
  * `:name_servers` - a list of DNS servers (optional)
  * `:domain` - DNS search domain (optional)

  Configuration normalization converts `:netmask` to `:prefix_length`.
  """

  alias VintageNet.Interface.RawConfig
  alias VintageNet.{Command, IP}

  @doc """
  Normalize the IPv4 parameters in a configuration.
  """
  @spec normalize(map()) :: %{ipv4: map()}
  def normalize(%{ipv4: ipv4} = config) do
    new_ipv4 = normalize_by_method(ipv4)
    %{config | ipv4: new_ipv4}
  end

  def normalize(config) do
    # No IPv4 configuration, so default to DHCP
    Map.put(config, :ipv4, %{method: :dhcp})
  end

  defp normalize_by_method(%{method: :dhcp}), do: %{method: :dhcp}
  defp normalize_by_method(%{method: :disabled}), do: %{method: :disabled}

  defp normalize_by_method(%{method: :static} = ipv4) do
    new_prefix_length = get_prefix_length(ipv4)

    ipv4
    |> normalize_address()
    |> Map.put(:prefix_length, new_prefix_length)
    |> normalize_gateway()
    |> normalize_name_servers()
    |> Map.take([
      :method,
      :address,
      :prefix_length,
      :gateway,
      :domain,
      :name_servers
    ])
  end

  defp normalize_by_method(_other) do
    raise ArgumentError, "specify an IPv4 address method (:disabled, :dhcp, or :static)"
  end

  defp normalize_address(%{address: address} = config),
    do: %{config | address: IP.ip_to_tuple!(address)}

  defp normalize_address(_config),
    do: raise(ArgumentError, "IPv4 :address key missing in static config")

  defp normalize_gateway(%{gateway: gateway} = config),
    do: %{config | gateway: IP.ip_to_tuple!(gateway)}

  defp normalize_gateway(config), do: config

  defp normalize_name_servers(%{name_servers: servers} = config) when is_list(servers) do
    %{config | name_servers: Enum.map(servers, &IP.ip_to_tuple!/1)}
  end

  defp normalize_name_servers(%{name_servers: one_server} = config) do
    %{config | name_servers: [IP.ip_to_tuple!(one_server)]}
  end

  defp normalize_name_servers(config), do: config

  defp get_prefix_length(%{prefix_length: prefix_length}), do: prefix_length

  defp get_prefix_length(%{netmask: mask}) do
    with {:ok, mask_as_tuple} <- IP.ip_to_tuple(mask),
         {:ok, prefix_length} <- IP.subnet_mask_to_prefix_length(mask_as_tuple) do
      prefix_length
    else
      {:error, _reason} ->
        raise ArgumentError, "invalid subnet mask #{inspect(mask)}"
    end
  end

  defp get_prefix_length(_unspecified),
    do: raise(ArgumentError, "specify :prefix_length or :netmask")

  @doc """
  Add IPv4 configuration commands for supporting static and dynamic IP addressing
  """
  @spec add_config(RawConfig.t(), map(), keyword()) :: RawConfig.t()
  def add_config(
        %RawConfig{
          ifname: ifname,
          up_cmds: up_cmds,
          down_cmds: down_cmds
        } = raw_config,
        %{ipv4: %{method: :disabled}},
        _opts
      ) do
    # Even though IPv4 is disabled, the interface is still brought up
    new_up_cmds = up_cmds ++ [{:run, "ip", ["link", "set", ifname, "up"]}]

    new_down_cmds =
      down_cmds ++
        [
          {:run_ignore_errors, "ip", ["addr", "flush", "dev", ifname, "label", ifname]},
          {:run, "ip", ["link", "set", ifname, "down"]}
        ]

    %RawConfig{
      raw_config
      | up_cmds: new_up_cmds,
        down_cmds: new_down_cmds
    }
  end

  def add_config(
        %RawConfig{
          ifname: ifname,
          child_specs: child_specs,
          up_cmds: up_cmds,
          down_cmds: down_cmds
        } = raw_config,
        %{ipv4: %{method: :dhcp}} = config,
        _opts
      ) do
    new_up_cmds = up_cmds ++ [{:run, "ip", ["link", "set", ifname, "up"]}]

    new_down_cmds =
      down_cmds ++
        [
          {:run_ignore_errors, "ip", ["addr", "flush", "dev", ifname, "label", ifname]},
          {:run, "ip", ["link", "set", ifname, "down"]}
        ]

    hostname = config[:hostname] || get_hostname()

    new_child_specs =
      child_specs ++
        [
          Supervisor.child_spec(
            {VintageNet.Interface.IfupDaemon,
             [
               ifname: ifname,
               command: "udhcpc",
               args: [
                 "-f",
                 "-i",
                 ifname,
                 "-x",
                 "hostname:#{hostname}",
                 "-s",
                 BEAMNotify.bin_path()
               ],
               opts:
                 Command.add_muon_options(
                   stderr_to_stdout: true,
                   log_output: :debug,
                   log_prefix: "udhcpc(#{ifname}): ",
                   env: BEAMNotify.env(name: "vintage_net_comm", report_env: true)
                 )
             ]},
            id: :udhcpc
          ),
          {VintageNet.Connectivity.InternetChecker, ifname}
        ]

    %RawConfig{
      raw_config
      | up_cmds: new_up_cmds,
        down_cmds: new_down_cmds,
        child_specs: new_child_specs
    }
  end

  def add_config(
        %RawConfig{
          ifname: ifname,
          up_cmds: up_cmds,
          down_cmds: down_cmds,
          child_specs: child_specs
        } = raw_config,
        %{ipv4: %{method: :static} = ipv4},
        _opts
      ) do
    addr_subnet = IP.cidr_to_string(ipv4.address, ipv4.prefix_length)

    broadcast_addr =
      IP.ipv4_broadcast_address(ipv4.address, ipv4.prefix_length) |> IP.ip_to_string()

    route_manager_up =
      case ipv4[:gateway] do
        nil ->
          {:fun, VintageNet.RouteManager, :clear_route, [ifname]}

        gateway ->
          {:fun, VintageNet.RouteManager, :set_route,
           [ifname, [{ipv4.address, ipv4.prefix_length}], gateway]}
      end

    resolver_up =
      case ipv4[:name_servers] do
        nil -> {:fun, VintageNet.NameResolver, :clear, [ifname]}
        [] -> {:fun, VintageNet.NameResolver, :clear, [ifname]}
        servers -> {:fun, VintageNet.NameResolver, :setup, [ifname, ipv4[:domain], servers]}
      end

    new_up_cmds =
      up_cmds ++
        [
          {:run_ignore_errors, "ip", ["addr", "flush", "dev", ifname, "label", ifname]},
          {:run, "ip",
           [
             "addr",
             "add",
             addr_subnet,
             "dev",
             ifname,
             "broadcast",
             broadcast_addr,
             "label",
             ifname
           ]},
          {:run, "ip", ["link", "set", ifname, "up"]},
          route_manager_up,
          resolver_up
        ]

    new_down_cmds =
      down_cmds ++
        [
          {:fun, VintageNet.RouteManager, :clear_route, [ifname]},
          {:fun, VintageNet.NameResolver, :clear, [ifname]},
          {:run_ignore_errors, "ip", ["addr", "flush", "dev", ifname, "label", ifname]},
          {:run, "ip", ["link", "set", ifname, "down"]}
        ]

    # If there's a default gateway, then check for internet connectivity.
    checker =
      case ipv4[:gateway] do
        nil -> {VintageNet.Connectivity.LANChecker, ifname}
        _exists -> {VintageNet.Connectivity.InternetChecker, ifname}
      end

    new_child_specs = child_specs ++ [checker]

    %RawConfig{
      raw_config
      | up_cmds: new_up_cmds,
        down_cmds: new_down_cmds,
        child_specs: new_child_specs
    }
  end

  defp get_hostname() do
    {:ok, hostname} = :inet.gethostname()
    to_string(hostname)
  end
end
