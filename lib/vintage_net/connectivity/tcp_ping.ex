defmodule VintageNet.Connectivity.TCPPing do
  @moduledoc """
  Test connectivity by making a connection using TCP

  Connectivity with a remote host can be checked by making a TCP connection to
  it. The connection either works, the connection is refused, or it times out.
  The first two cases indicate connectivity.

  Normally ICMP is used for testing connectivity, but that requires the new
  socket API and a Linux kernel with `net.ipv4.ping_group_range` enabled.  This
  way usually works unless a device is behind a strict firewall, but there's
  usually at least one IP address/port on the Internet that they allow.
  """
  @ping_timeout 5_000

  @type ping_error_reason :: :if_not_found | :no_ipv4_address | :verify_failed | :inet.posix()

  @type ping_target ::
          {hostname :: VintageNet.any_ip_address(), address :: VintageNet.any_ip_address(),
           port :: non_neg_integer()}

  @type verify_fun :: (:gen_tcp.socket(), VintageNet.ifname(), ping_target() -> boolean())

  @type verify_callback :: verify_fun() | {module(), atom()}

  @doc """
  Check connectivity with another device

  The "ping" is really a TCP connection attempt from the specified interface to
  an IP address and port. Failures to connect don't necessarily mean that the
  Internet is down, but it's likely especially if the server that's specified
  in the configuration is highly available.

  Source IP-based routing is required for the TCP connect to go out the right
  network interface. This is configured by default when using VintageNet.
  """
  @spec ping(VintageNet.ifname(), ping_target(), verify_callback()) ::
          :ok | {:error, ping_error_reason()}
  def ping(
        ifname,
        {_hostname, host, _port} = ping_target,
        verify_callback \\ Application.get_env(:vintage_net, :internet_host_verify_callback)
      ) do
    # Note: No support for DNS since DNS can't be forced through an
    # interface. I.e., errors on other interfaces mess up DNS even if the
    # one of interest is ok.
    with {:ok, dest_ip} <- VintageNet.IP.ip_to_tuple(host),
         {:ok, src_ip} <- get_interface_address(ifname, family(dest_ip)) do
      connect_and_verify(verify_callback, ifname, ping_target, src_ip, dest_ip)
    else
      {:error, :econnrefused} ->
        # If the remote refuses the connection, then that means that it
        # received it and we're connected to the internet!
        :ok

      {:error, reason} ->
        {:error, reason}

      posix_error ->
        {:error, posix_error}
    end
  end

  defp get_interface_address(ifname, family) do
    with {:ok, addresses} <- :inet.getifaddrs(),
         {:ok, params} <- find_addresses_on_interface(addresses, ifname) do
      find_ip_addr(params, family)
    end
  end

  defp find_addresses_on_interface(addresses, ifname) do
    ifname_cl = to_charlist(ifname)

    case Enum.find(addresses, fn {k, _v} -> k == ifname_cl end) do
      {^ifname_cl, params} -> {:ok, params}
      _ -> {:error, :if_not_found}
    end
  end

  defp find_ip_addr(params, family) do
    case Enum.find(params, &ip_addr?(family, &1)) do
      {:addr, addr} -> {:ok, addr}
      _ -> {:error, :no_suitable_ip_address}
    end
  end

  defp ip_addr?(:inet, {:addr, {_, _, _, _}}), do: true
  defp ip_addr?(:inet6, {:addr, {_, _, _, _, _, _, _, _}}), do: true
  defp ip_addr?(_family, _), do: false

  defp family({_, _, _, _}), do: :inet
  defp family({_, _, _, _, _, _, _, _}), do: :inet6

  # If no verify callback was given, then just attempt to connect.
  defp connect_and_verify(nil, _ifname, {_hostname, _host, port}, src_ip, dest_ip) do
    case :gen_tcp.connect(dest_ip, port, [ip: src_ip], @ping_timeout) do
      {:ok, tcp} ->
        _ = :gen_tcp.close(tcp)
        :ok

      {:error, :econnrefused} ->
        # If the remote refuses the connection, then that means that it
        # received it and we're connected to the internet!
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp connect_and_verify(verify_callback, ifname, {_, _, port} = ping_target, src_ip, dest_ip) do
    with {:ok, tcp} <- :gen_tcp.connect(dest_ip, port, [ip: src_ip], @ping_timeout),
         true <- do_verify(verify_callback, tcp, ifname, ping_target) do
      _ = :gen_tcp.close(tcp)
    else
      {:error, reason} ->
        {:error, reason}

      false ->
        {:error, :verify_failed}

      posix_error ->
        {:error, posix_error}
    end
  end

  defp do_verify(fun, tcp_socket, ifname, ping_target) when is_function(fun, 3) do
    fun.(tcp_socket, ifname, ping_target)
  end

  defp do_verify({module, fun}, tcp_socket, ifname, ping_target) do
    apply(module, fun, [tcp_socket, ifname, ping_target])
  end
end
