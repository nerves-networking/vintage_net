defmodule VintageNet.Connectivity.SSLConnect do
  @moduledoc """
  Test connectivity by making a connection using SSL

  Connectivity with a remote host can be checked by making a SSL connection to
  it. The connection either works, the connection is refused, or it times out.
  The first two cases indicate connectivity.
  """

  import VintageNet.Connectivity.TCPPing, only: [get_interface_address: 2]
  alias VintageNet.Connectivity.HostList
  require Logger

  @connect_timeout 5_000

  @doc """
  Check connectivity with another device

  The "connect" is a SSL connection attempt from the specified interface to
  an IP address and port. Failures to connect don't necessarily mean that the
  Internet is down, but it's likely especially if the server that's specified
  in the configuration is highly available.
  """
  @spec connect(VintageNet.ifname(), HostList.options()) :: :ok | {:error, :inet.posix()}
  def connect(ifname, opts) do
    host = Keyword.fetch!(opts, :host)
    port = Keyword.fetch!(opts, :port)

    with {:ok, src_ip} <- get_interface_address(ifname, :inet),
         {:ok, ssl} <-
           :ssl.connect(
             to_charlist(host),
             port,
             connect_opts(src_ip),
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

  defp connect_opts(src_ip) do
    base = [
      verify: :verify_peer,
      active: false,
      ip: src_ip
    ]

    if Code.ensure_loaded?(:public_key) and function_exported?(:public_key, :cacerts_get, 0) do
      cacerts = apply(:public_key, :cacerts_get, [])
      Keyword.put(base, :cacerts, cacerts)
    else
      Logger.warning("SSLConnect support on OTP 24 is limited due to lack of cacerts")
      # remove the verify_peer option, since we don't have CA certs
      Keyword.delete(base, :verify)
    end
  end
end
