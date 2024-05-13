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

  alias VintageNet.Connectivity.SSLPing.PublicKey
  require Logger

  @connect_timeout 5_000

  @impl VintageNet.Connectivity.Ping
  def normalize({__MODULE__, opts}) do
    with {:ok, host} when is_binary(host) <- Keyword.fetch(opts, :host),
         port when port > 0 and port < 65535 <- Keyword.get(opts, :port, 443),
         {:ok, {module, function, args} = mfa}
         when is_atom(module) and is_atom(function) and is_list(args) <-
           Keyword.get(opts, :connect_options_mfa, {PublicKey, :connect_options, []}) do
      {:ok, {__MODULE__, host: host, port: port, connection_options_mfa: mfa}}
    else
      _ -> :error
    end
  end

  @impl VintageNet.Connectivity.Ping
  def expand(spec) do
    # No expansion for SSL endpoints yet.
    [spec]
  end

  @doc """
  Check connectivity with another device

  The "ping" is a SSL connection attempt from the specified interface to
  an IP address and port. Failures to connect don't necessarily mean that the
  Internet is down, but it's likely especially if the server that's specified
  in the configuration is highly available.
  """
  @impl VintageNet.Connectivity.Ping
  def ping(ifname, {__MODULE__, opts}) do
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
    {module, function, args} = Keyword.fetch!(opts, :connect_options_mfa)
    apply(module, function, args)
  end

  defp connect_opts(initial_opts, src_ip) do
    initial_opts
    |> Keyword.put(:active, false)
    |> Keyword.put(:ip, src_ip)
  end
end
