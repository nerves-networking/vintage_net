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
  @behaviour VintageNet.Connectivity.Check

  import Record, only: [defrecord: 2]

  @ping_timeout 5_000

  @type hostent() :: record(:hostent, [])

  defrecord :hostent, Record.extract(:hostent, from_lib: "kernel/include/inet.hrl")

  @type ping_error_reason() :: :if_not_found | :no_suitable_ip_address | :inet.posix()

  @impl VintageNet.Connectivity.Check
  def normalize({__MODULE__, opts}) do
    with {:ok, host} <- Keyword.fetch(opts, :host),
         {:ok, port} when port > 0 and port < 65535 <- Keyword.fetch(opts, :port) do
      case VintageNet.IP.ip_to_tuple(host) do
        {:ok, host_as_tuple} -> {__MODULE__, host: host_as_tuple, port: port}
        # Likely a domain name
        {:error, _} when is_binary(host) -> {__MODULE__, host: host, port: port}
        _ -> :error
      end
    else
      _ -> :error
    end
  end

  @impl VintageNet.Connectivity.Check
  def expand({__MODULE__, opts}) do
    port = Keyword.fetch!(opts, :port)

    case Keyword.fetch!(opts, :host) do
      ip when is_tuple(ip) ->
        [{__MODULE__, opts}]

      host when is_binary(host) ->
        case :inet.gethostbyname(String.to_charlist(host)) do
          {:ok, hostent(h_addr_list: addresses)} ->
            for address <- addresses, do: {__MODULE__, host: address, port: port}

          _error ->
            # DNS not working, so the internet is not working enough
            # to consider this host
            []
        end
    end
  end

  @doc """
  Check connectivity with another device

  The check is really a TCP connection attempt from the specified interface to
  an IP address and port. Failures to connect don't necessarily mean that the
  Internet is down, but it's likely especially if the server that's specified
  in the configuration is highly available.

  Source IP-based routing is required for the TCP connect to go out the right
  network interface. This is configured by default when using VintageNet.
  """
  @impl VintageNet.Connectivity.Check
  def check(ifname, {__MODULE__, opts}) do
    host = Keyword.fetch!(opts, :host)
    port = Keyword.fetch!(opts, :port)
    # Note: No support for DNS since DNS can't be forced through an
    # interface. I.e., errors on other interfaces mess up DNS even if the
    # one of interest is ok.
    with {:ok, dest_ip} <- VintageNet.IP.ip_to_tuple(host),
         {:ok, tcp} <-
           :gen_tcp.connect(dest_ip, port, bind_to_device_option(ifname), @ping_timeout) do
      _ = :gen_tcp.close(tcp)
      {:ok, {evaluate_result(dest_ip), []}}
    else
      {:error, :econnrefused} ->
        # If the remote refuses the connection, then that means that it
        # received it and we're connected to the internet!
        {:ok, dest_ip} = VintageNet.IP.ip_to_tuple(host)
        {:ok, {evaluate_result(dest_ip), []}}

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

  # Categorize obvious non-Internet IP addresses
  defp evaluate_result({192, 168, _, _}), do: :lan
  defp evaluate_result({172, b, _, _}) when b in 16..31, do: :lan
  defp evaluate_result({10, _, _, _}), do: :lan
  defp evaluate_result({127, _, _, _}), do: :lan
  defp evaluate_result({0, 0, 0, 0, 0, 0, 0, 1}), do: :lan
  defp evaluate_result(_), do: :internet
end
