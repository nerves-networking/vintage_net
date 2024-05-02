defmodule VintageNet.Connectivity.SSLConnect do
  @moduledoc """
  Test connectivity by making a connection using SSL

  Connectivity with a remote host can be checked by making a SSL connection to
  it. The connection either works, the connection is refused, or it times out.
  The first two cases indicate connectivity.
  """

  import VintageNet.Connectivity.TCPPing, only: [get_interface_address: 2]

  @connect_timeout 5_000

  @doc """
  Check connectivity with another device

  The "connect" is a SSL connection attempt from the specified interface to
  an IP address and port. Failures to connect don't necessarily mean that the
  Internet is down, but it's likely especially if the server that's specified
  in the configuration is highly available.
  """
  @spec connect(VintageNet.ifname(), {String.t(), port}) :: :ok | {:error, :inet.posix()}
  def connect(ifname, {hostname, port}) do
    with {:ok, src_ip} <- get_interface_address(ifname, :inet),
         {:ok, ssl} <-
           :ssl.connect(
             to_charlist(hostname),
             port,
             [
               verify: :verify_peer,
               cacerts: :public_key.cacerts_get(),
               active: false,
               ip: src_ip
             ],
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
end
