defmodule VintageNet.IP.ConfigToInterfaces do
  @moduledoc """
  This is a helper module for VintageNet.Technology implementations that use
  IPv4.
  """

  @doc """
  Convert a configuration to the contents of a /etc/interfaces file

  The IPv4 configuration should be specified in the map under the `:ipv4` key.
  Fields are:

  * `:method` - `:dhcp` or `:static`

  If `method: :static`, then the following addition fields are checked:

  * `:address` - IPv4 address as a string
  * `:netmask` - IPv4 netmask as a string
  * `:broadcast` - IPv4 broadcast address as a string
  * `:metric` - Route metric (TODO: THIS WON'T WORK)
  * `:gateway` - Default gateway (TODO: THIS WON'T WORK)
  * `:pointopoint` - Address of the other end point
  * `:hwaddress` - Set the MAC address
  * `:mtu` - Set the MTU
  * `:scope` - Route scope (TODO: THIS WON'T WORK)

  """
  @spec config_to_interfaces_contents(VintageNet.ifname(), map()) :: String.t()
  def config_to_interfaces_contents(ifname, %{ipv4: %{method: :dhcp} = ipv4} = config) do
    hostname = config[:hostname] || get_hostname()
    "iface #{ifname} inet dhcp" <> dhcp_options(ipv4, hostname)
  end

  def config_to_interfaces_contents(ifname, %{ipv4: %{method: :static} = ipv4} = config) do
    hostname = config[:hostname] || get_hostname()
    "iface #{ifname} inet static" <> static_options(ipv4, hostname)
  end

  # Default to DHCP
  def config_to_interfaces_contents(ifname, config) do
    hostname = config[:hostname] || get_hostname()
    "iface #{ifname} inet dhcp" <> dhcp_options(config, hostname)
  end

  defp dhcp_options(_ipv4, hostname) do
    """

      script #{udhcpc_handler_path()}
      hostname #{hostname}
    """
  end

  defp static_options(ipv4, hostname) do
    contents =
      ipv4
      |> Map.take([
        :address,
        :netmask,
        :broadcast,
        :metric,
        :gateway,
        :pointopoint,
        :hwaddress,
        :mtu,
        :scope
      ])
      |> Enum.map(fn {option, value} -> "#{option} #{value}" end)
      |> Enum.join("\n  ")

    """

      #{contents}
      hostname #{hostname}
    """
  end

  defp get_hostname do
    {:ok, hostname} = :inet.gethostname()
    to_string(hostname)
  end

  defp udhcpc_handler_path() do
    Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])
  end
end
