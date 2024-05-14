defmodule VintageNet.Connectivity.HTTP do
  @ping_timeout 5_000

  @behaviour VintageNet.Connectivity.Check

  require Logger

  @impl VintageNet.Connectivity.Check
  def normalize({__MODULE__, opts}) do
    with {:ok, host} <- Keyword.fetch(opts, :host),
         {:ok, port} when port > 0 and port < 65535 <- Keyword.fetch(opts, :port),
         {:ok, path} <- Keyword.fetch(opts, :path),
         {:ok, match} <- Keyword.fetch(opts, :match) do
      case match do
        %Regex{} ->
          {__MODULE__, host: host, port: port, path: path, match: match}

        regex ->
          {:ok, regex_match} = Regex.compile(match)
          {__MODULE__, host: host, port: port, path: path, match: regex_match}
      end
    else
      _ -> :error
    end
  end

  @impl VintageNet.Connectivity.Check
  def expand({__MODULE__, opts}) do
    # {VintageNet.Connectivity.TCPPing, opts}
    # |> VintageNet.Connectivity.TCPPing.expand()
    # |> Enum.map(fn {VintageNet.Connectivity.TCPPing, expanded} -> {__MODULE__, Keyword.merge(opts, expanded)} end)
    [{__MODULE__, opts}]
  end

  @impl VintageNet.Connectivity.Check
  def check(ifname, {__MODULE__, opts}) do
    host = Keyword.fetch!(opts, :host)
    port = Keyword.fetch!(opts, :port)
    path = Keyword.fetch!(opts, :path)
    match = Keyword.fetch!(opts, :match)

    # Note: No support for DNS since DNS can't be forced through an
    # interface. I.e., errors on other interfaces mess up DNS even if the
    # one of interest is ok.
    case :httpc.request(
           :get,
           {uri(host, port, path), [{~c"User-Agent", ~c"vintage_net"}]},
           [timeout: @ping_timeout],
           body_format: :binary,
           socket_opts: socket_opts(ifname)
         ) do
      {:ok, {_status, _headers, body}} ->
        if String.match?(body, match) do
          {:ok, :internet}
        else
          Logger.error(%{connectivity_check_match: {body, match}})
          {:error, :match}
        end

      {:error, :econnrefused} ->
        # If the remote refuses the connection, then that means that it
        # received it and we're connected to the internet!
        {:ok, :internet}

      {:error, reason} ->
        {:error, reason}

      posix_error ->
        {:error, posix_error}
    end
  end

  defp uri(dest_ip, port, path) do
    host = VintageNet.IP.ip_to_string(dest_ip)
    ~c"http://#{host}:#{port}/#{path}"
  end

  defp socket_opts(ifname) do
    case :os.type() do
      {:unix, :linux} -> [ipfamily: :inet6fb4, bind_to_device: ifname]
      _ -> [ipfamily: :inet6fb4]
    end
  end
end
