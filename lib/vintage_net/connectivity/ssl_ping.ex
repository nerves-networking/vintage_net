defmodule VintageNet.Connectivity.SSLPing do
  @moduledoc """
  Test connectivity by making a connection using SSL

  Connectivity with a remote host can be checked by making a SSL connection to
  it. The connection either works, the connection is refused, or it times out.
  The first two cases indicate connectivity.

  This module should be configured with a `:connect_opts_mfa` option. It should
  implement the `VintageNet.Connectivity.SSLPing.ConnectOptions` behaviour.
  The default implementation will use `:public_key.cacerts_get()` which can
  potentially be insecure.
  """

  @behaviour VintageNet.Connectivity.Ping

  import VintageNet.Connectivity.TCPPing, only: [get_interface_address: 2]
  alias VintageNet.Connectivity.HostList
  alias VintageNet.Connectivity.SSLPing.PublicKey
  require Logger

  @connect_timeout 5_000

  @doc """
  Check connectivity with another device

  The "ping" is a SSL connection attempt from the specified interface to
  an IP address and port. Failures to connect don't necessarily mean that the
  Internet is down, but it's likely especially if the server that's specified
  in the configuration is highly available.
  """
  @impl VintageNet.Connectivity.Ping
  @spec ping(VintageNet.ifname(), HostList.options()) :: :ok | {:error, :inet.posix()}
  def ping(ifname, opts) do
    host = Keyword.fetch!(opts, :host)
    port = Keyword.fetch!(opts, :port)
    initial_opts = get_connect_options(opts)

    with {:ok, src_ip} <- get_interface_address(ifname, :inet),
         {:ok, ssl} <-
           :ssl.connect(
             to_charlist(host),
             port,
             connect_opts(initial_opts, src_ip),
             @connect_timeout
           ) do
      _ = :ssl.close(ssl)
      :ok
    else
      {:error, reason} ->
        {:error, reason}

      posix_error ->
        {:error, posix_error}
    end
  end

  defp get_connect_options(opts) do
    module = Keyword.get(opts, :connect_options_impl, PublicKey)
    module.connect_options()
  end

  defp connect_opts(initial_opts, src_ip) do
    initial_opts
    |> Keyword.put(:active, false)
    |> Keyword.put(:ip, src_ip)
  end
end
