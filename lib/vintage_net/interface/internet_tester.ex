defmodule VintageNet.Interface.InternetTester do
  @moduledoc """
  This module contains functions for testing whether the Internet is available.

  See the InternetConnectivityChecker for a GenServer that checks on regular
  intervals and updates VintageNet properties as needed.
  """
  @ping_timeout 5_000

  @type ping_error_reason :: :if_not_found | :no_ipv4_address | :inet.posix()

  @doc """
  Check connectivity with another device

  The "ping" is really a TCP connection attempt from the specified interface to
  an IP address and port. Failures to connect don't necessarily mean that the
  Internet is down, but it's likely especially if the server that's specified
  in the configuration is highly available.

  Source IP-based routing is required for the TCP connect to go out the right
  network interface. This is configured by default when using VintageNet.
  """
  @spec ping(VintageNet.ifname(), {VintageNet.any_ip_address(), non_neg_integer()}) ::
          :ok | {:error, ping_error_reason()}
  def ping(ifname, {host, port}) do
    with {:ok, src_ip} <- get_interface_address(ifname),
         # Note: No support for DNS since DNS can't be forced through
         # an interface. I.e., errors on other interfaces mess up DNS
         # even if the one of interest is ok.
         {:ok, dest_ip} <- VintageNet.IP.ip_to_tuple(host),
         {:ok, tcp} <- :gen_tcp.connect(dest_ip, port, [ip: src_ip], @ping_timeout) do
      _ = :gen_tcp.close(tcp)
      :ok
    else
      {:error, reason} -> {:error, reason}
      posix_error -> {:error, posix_error}
    end
  end

  defp get_interface_address(ifname) do
    with {:ok, addresses} <- :inet.getifaddrs(),
         {:ok, params} <- find_addresses_on_interface(addresses, ifname) do
      find_ipv4_addr(params)
    end
  end

  defp find_addresses_on_interface(addresses, ifname) do
    ifname_cl = to_charlist(ifname)

    case Enum.find(addresses, fn {k, _v} -> k == ifname_cl end) do
      {^ifname_cl, params} -> {:ok, params}
      _ -> {:error, :if_not_found}
    end
  end

  defp find_ipv4_addr(params) do
    case Enum.find(params, &ipv4_addr?/1) do
      {:addr, ipv4_addr} -> {:ok, ipv4_addr}
      _ -> {:error, :no_ipv4_address}
    end
  end

  defp ipv4_addr?({:addr, {_, _, _, _}}), do: true
  defp ipv4_addr?(_), do: false
end
