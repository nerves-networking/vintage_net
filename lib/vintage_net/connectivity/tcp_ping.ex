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
    # Note: No support for DNS since DNS can't be forced through an
    # interface. I.e., errors on other interfaces mess up DNS even if the
    # one of interest is ok.
    with {:ok, dest_ip} <- VintageNet.IP.ip_to_tuple(host),
         {:ok, tcp} <-
           :gen_tcp.connect(dest_ip, port, bind_to_device_option(ifname), @ping_timeout) do
      _ = :gen_tcp.close(tcp)
      :ok
    else
      {:error, :econnrefused} ->
        # If the remote refuses the connection, then that means that it
        # received it and we're connected to the internet!
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp bind_to_device_option(ifname) do
    case :os.type() do
      {:unix, :linux} -> [bind_to_device: ifname]
      _ -> []
    end
  end
end
