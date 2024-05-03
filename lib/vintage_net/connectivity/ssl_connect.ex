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
    initial_opts = get_initial_opts(opts)

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

  defp get_initial_opts(opts) do
    {module, fun, args} =
      Keyword.get(opts, :connect_opts_mfa, {__MODULE__, :default_connect_opts, []})

    apply(module, fun, args)
  end

  defp connect_opts(initial_opts, src_ip) do
    initial_opts
    |> Keyword.put(:active, false)
    |> Keyword.put(:ip, src_ip)
  end

  @doc false
  if :erlang.system_info(:otp_release) in [~c"21", ~c"22", ~c"23", ~c"24"] do
    def default_connect_opts() do
      Logger.warning("SSLConnect support on OTP 24 is limited due to lack of cacerts")
      []
    end
  else
    def default_connect_opts() do
      [
        cacerts: :public_key.cacerts_get(),
        verify: :verify_peer
      ]
    end
  end
end
