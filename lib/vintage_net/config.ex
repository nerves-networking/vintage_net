defmodule VintageNet.Config do
  @doc """
  Builds a vintage network configuration
  """
  def make(networks, opts \\ []) do
    Enum.reduce(networks, %{}, fn network, _config ->
      do_make(network, opts)
    end)
  end

  defp do_make(%{pppd: pppd}, _opts) do
    options = Enum.join(pppd.options, " ")

    pppd_up_cmd =
      "pppd connect \"#{pppd.chat_bin} -v -f #{pppd.provider}\" #{pppd.ttyname} #{pppd.speed} " <>
        options

    %{
      network_interfaces: "",
      up_cmds: ["mknod /dev/ppp c 108 0", pppd_up_cmd],
      down_cmds: ["killall -q pppd"]
    }
  end

  defp do_make(network, opts) do
    with {:ok, ip_version} <- get_ip_version(network),
         {:ok, address_method} <- get_address_method(network, ip_version),
         up_cmds <- build_up_cmds(network, opts),
         down_cmds <- build_down_cmds(network, opts),
         address_family <- ip_version_to_inet_family(ip_version) do
      %{
        network_interfaces: "iface eth0 #{address_family} #{address_method}",
        up_cmds: up_cmds,
        down_cmds: down_cmds
      }
    end
  end

  defp ip_version_to_inet_family(:ipv4), do: "inet"
  defp ip_version_to_inet_family(:ipv6), do: "inet6"

  defp build_up_cmds(network, opts) do
    with {:ok, ifup} <- Keyword.fetch(opts, :ifup),
         {:ok, file} <- Keyword.fetch(opts, :interfaces_file) do
      ["#{ifup} -i #{file} #{network.ifname}"]
    end
  end

  defp build_down_cmds(network, opts) do
    with {:ok, ifdown} <- Keyword.fetch(opts, :ifdown),
         {:ok, file} <- Keyword.fetch(opts, :interfaces_file) do
      ["#{ifdown} -i #{file} #{network.ifname}"]
    end
  end

  defp get_address_method(network, ip_version) do
    case Map.get(network, ip_version) do
      nil ->
        {:error, :no_address_method}

      ip_config ->
        {:ok, ip_config.method}
    end
  end

  defp get_ip_version(network) do
    cond do
      Map.has_key?(network, :ipv4) ->
        {:ok, :ipv4}

      Map.has_key?(network, :ipv6) ->
        {:ok, :ipv6}

      true ->
        {:error, :unknown_ip_version}
    end
  end
end
