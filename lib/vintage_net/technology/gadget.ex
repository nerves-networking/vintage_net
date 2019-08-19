defmodule VintageNet.Technology.Gadget do
  @behaviour VintageNet.Technology

  alias VintageNet.Interface.RawConfig
  alias VintageNet.IP.IPv4Config

  @moduledoc """
  Support for USB Gadget virtual Ethernet interface configurations

  USB Gadget interfaces expose a virtual Ethernet port that has a static
  IP. This runs a simple DHCP server for assigning an IP address to the
  computer at the other end of the USB cable. IP addresses are computed
  based on the hostname and interface name. A /30 subnet is used for the
  two IP addresses for each side of the cable to try to avoid conflicts
  with IP subnets used on either computer.

  Configurations for this technology are maps with a `:type` field set
  to `VintageNet.Technology.Gadget`. Gadget-specific options are in
  a map under the `:gadget` key. These include:

  * `:hostname` - if non-nil, this overrides the hostname used for computing
    a unique IP address for this interface. If unset, `:inet.gethostname/0`
    is used.

  Most users should specify the following configuration:

  ```elixir
  %{type: VintageNet.Technology.Gadget}
  ```
  """
  @impl true
  def normalize(%{type: __MODULE__} = config) do
    gadget =
      Map.get(config, :gadget)
      |> normalize_gadget()

    %{type: __MODULE__, gadget: gadget}
  end

  defp normalize_gadget(%{hostname: hostname}) when is_binary(hostname) do
    %{hostname: hostname}
  end

  defp normalize_gadget(_gadget_config), do: %{}

  @impl true
  def to_raw_config(ifname, %{type: __MODULE__} = config, opts) do
    normalized_config = normalize(config)

    # Derive the subnet based on the ifname, but allow the user to force a hostname
    subnet =
      case normalized_config.gadget do
        %{hostname: hostname} ->
          OneDHCPD.IPCalculator.default_subnet(ifname, hostname)

        _ ->
          OneDHCPD.IPCalculator.default_subnet(ifname)
      end

    ipv4_config = %{
      ipv4: %{
        method: :static,
        address: OneDHCPD.IPCalculator.our_ip_address(subnet),
        prefix_length: OneDHCPD.IPCalculator.prefix_length()
      }
    }

    %RawConfig{
      ifname: ifname,
      type: __MODULE__,
      source_config: normalized_config,
      child_specs: [
        one_dhcpd_child_spec(ifname)
      ]
    }
    |> IPv4Config.add_config(ipv4_config, opts)
  end

  @impl true
  def ioctl(_ifname, _command, _args) do
    {:error, :unsupported}
  end

  @impl true
  def check_system(opts) do
    # TODO
    with :ok <- check_program(opts[:bin_ifup]) do
      :ok
    end
  end

  defp check_program(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, "Can't find #{path}"}
    end
  end

  defp one_dhcpd_child_spec(ifname) do
    %{
      id: {OneDHCPD, ifname},
      start: {OneDHCPD, :start_server, [ifname]}
    }
  end
end
