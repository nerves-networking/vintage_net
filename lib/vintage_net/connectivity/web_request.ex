defmodule VintageNet.Connectivity.WebRequest do
  @moduledoc """
  Test connectivity by making a HTTP request

  Connectivity with a remote host can be checked by making an HTTP request
  HEAD to it. The request either works, the connection is refused, or it times out.
  The first two cases indicate connectivity.

  This connectivity checker requires the following options:

  * `:url` - Required. HTTP URL for an Internet-reachable host
  * `:max_response_size` - Optional max response size in bytes. Defaults to 1024 bytes.
  * `:timeout_millis` - Optional time to wait for a response in milliseconds. Defaults to 5000 ms.
  * `match` - Required. Regex or String to check the request with
  """

  @behaviour VintageNet.Connectivity.Check
  alias VintageNet.Connectivity.HTTPClient
  require Logger

  @default_max_response_size 1024
  @default_timeout_millis 5_000

  @impl VintageNet.Connectivity.Check
  def normalize({__MODULE__, options}) do
    with {:ok, url_string} <- Keyword.fetch(options, :url),
         {:ok, url} <- URI.new(url_string),
         :ok <- validate_url(url),
         match = Keyword.get(options, :match),
         {:ok, regex_match} <- normalize_match(match) do
      {:ok,
       {__MODULE__,
        url: url,
        match: regex_match,
        max_response_size: Keyword.get(options, :max_response_size, @default_max_response_size),
        timeout_millis: Keyword.get(options, :timeout_millis, @default_timeout_millis)}}
    end
  end

  @doc "helper to validate a URL"
  @spec validate_url(URI.t()) :: :ok | {:error, :invalid_url}
  def validate_url(uri) do
    if uri.scheme == "http" and
         uri.port > 0 and uri.port < 65536 and
         byte_size(uri.host) > 1 do
      :ok
    else
      {:error, :invalid_url}
    end
  end

  defp normalize_match(%Regex{} = regex), do: {:ok, regex}
  defp normalize_match(match) when is_binary(match), do: Regex.compile(match)
  defp normalize_match(nil), do: {:ok, ~r/.*/}
  defp normalize_match(_), do: {:error, :unknown_match}

  @impl VintageNet.Connectivity.Check
  def expand({__MODULE__, opts}) do
    [{__MODULE__, opts}]
  end

  @impl VintageNet.Connectivity.Check
  def check(ifname, {__MODULE__, options}) do
    with {:ok, body} <- make_request(ifname, options) do
      evaluate_match(body, options[:match])
    else
      {:error, :econnrefused} ->
        # If the remote refuses the connection, then that means that someone
        # received it and we're connected at least connected to a LAN!
        {:ok, {:lan, []}}

      {:error, reason} ->
        {:error, reason}

      posix_error when is_atom(posix_error) ->
        {:error, posix_error}
    end
  end

  defp make_request(ifname, options) do
    request = HTTPClient.create_request(options[:url], ifname)

    case HTTPClient.make_request(request, options[:max_response_size], options[:timeout_millis]) do
      {:ok, {{_version, _status, _status_message}, _headers, body}} -> {:ok, body}
      error -> error
    end
  end

  # check the body against the supplied regex.
  # if the match evaluates successfully, we must have internet
  # otherwise, there may be a captive portal indicating lan connectivity
  @spec evaluate_match(String.t(), Regex.t()) ::
          {:ok, {VintageNet.connection_status(), [{[String.t()], any()}]}}
  defp evaluate_match(body, match) do
    if String.match?(body, match),
      do: {:ok, {:internet, []}},
      else: {:ok, {:lan, []}}
  end
end
