defmodule VintageNet.Connectivity.WebRequest do
  @moduledoc """
  Test connectivity by making a HTTP request

  Connectivity with a remote host can be checked by making an HTTP request
  to it. The request either works, the connection is refused, or it times out.
  The first two cases indicate connectivity.

  This connectivity cheker requires some options to work:

  * `host` - Required. hostname to connect to.
  * `port` - Required. port to make the HTTP connection to. Usually 80.
  * `path` - Required. URI path. for example `/connectiontest.txt`
  * `match` - Required. Regex or String to check the request with.
  * `nonce` - Optional. String to be used in query parameters to ensure result is not cached.
  """

  @behaviour VintageNet.Connectivity.Check
  alias VintageNet.Connectivity.HTTPClient
  require Logger

  @request_timeout 5_000

  @impl VintageNet.Connectivity.Check
  def normalize({__MODULE__, opts}) do
    with {:ok, host} <- Keyword.fetch(opts, :host),
         {:ok, port} when port > 0 and port < 65535 <- Keyword.fetch(opts, :port),
         {:ok, path} <- Keyword.fetch(opts, :path),
         match <- Keyword.get(opts, :match),
         nonce <- Keyword.get(opts, :nonce),
         {:ok, regex_match} <- normalize_match(match, nonce) do
      {__MODULE__, host: host, port: port, path: path, match: regex_match, nonce: nonce}
    else
      _ -> :error
    end
  end

  @spec normalize_match(nil | Regex.t() | String.t(), nil | String.t()) ::
          {:ok, Regex.t()} | {:error, term()}
  defp normalize_match(%Regex{} = regex, _), do: {:ok, regex}
  defp normalize_match(match, _) when is_binary(match), do: Regex.compile(match)
  defp normalize_match(nil, nonce) when is_binary(nonce), do: Regex.compile(nonce)
  defp normalize_match(_, _), do: {:error, :unknown_match}

  @impl VintageNet.Connectivity.Check
  def expand({__MODULE__, opts}) do
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
           {uri(host, port, path, ""), [{~c"User-Agent", ~c"vintage_net"}]},
           [timeout: @ping_timeout],
           body_format: :binary,
           socket_opts: socket_opts(ifname)
         ) do
      {:ok, {_status, _headers, body}} ->
        # check the body against the supplied regex.
        # if the match evalutates successfully, we must have internet
        # otherwise, there may be a captive portal indicating lan connectivity
        if String.match?(body, match), do: {:ok, :internet}, else: {:ok, :lan}

      {:error, :econnrefused} ->
        # If the remote refuses the connection, then that means that somebody
        # received it and we may or may not be connected to the internet!
        {:ok, :lan}

      {:error, reason} ->
        {:error, reason}

      posix_error ->
        {:error, posix_error}
    end
  end

  defp uri(dest_ip, port, path, query) do
    host = VintageNet.IP.ip_to_string(dest_ip)
    %URI{host: host, port: port, path: path, query: query}
  end

  defp socket_opts(ifname) do
    case :os.type() do
      {:unix, :linux} -> [ipfamily: :inet6fb4, bind_to_device: ifname]
      _ -> [ipfamily: :inet6fb4]
    end
  end
end
