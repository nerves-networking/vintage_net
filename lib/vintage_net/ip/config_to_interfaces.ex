defmodule VintageNet.IP.ConfigToInterfaces do
  @moduledoc """
  Common config for ifup ip configs
  """

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
