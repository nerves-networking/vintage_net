defmodule VintageNet.Connectivity.WhenWhere do
  @moduledoc """
  Connectivity tester that understands how to make requests to
  a [whenwhere](http://whenwhere.nervesproject.org) server.


  This connectivity checker requires the following options:

  * `:url` - Required. HTTP URL for an Internet-reachable host
  * `:max_response_size` - Optional max response size in bytes. Defaults to 1024 bytes.
  * `:timeout_millis` - Optional time to wait for a response in milliseconds. Defaults to 5000 ms.
  """

  @behaviour VintageNet.Connectivity.Check
  import VintageNet.Connectivity.TCPPing, only: [get_interface_address: 2]
  import VintageNet.Connectivity.WebRequest, only: [validate_url: 1]

  alias VintageNet.Connectivity.HTTPClient
  require Logger

  @default_max_response_size 1024
  @default_timeout_millis 5_000

  @impl VintageNet.Connectivity.Check
  def normalize({__MODULE__, options}) do
    with {:ok, url_string} <- Keyword.fetch(options, :url),
         {:ok, url} <- URI.new(url_string),
         :ok <- validate_url(url) do
      {:ok,
       {__MODULE__,
        url: url,
        max_response_size: Keyword.get(options, :max_response_size, @default_max_response_size),
        timeout_millis: Keyword.get(options, :timeout_millis, @default_timeout_millis)}}
    else
      _ -> :error
    end
  end

  @impl VintageNet.Connectivity.Check
  def expand({__MODULE__, opts}) do
    [{__MODULE__, opts}]
  end

  @impl VintageNet.Connectivity.Check
  def check(ifname, {__MODULE__, options}) do
    nonce = Base.encode16(:rand.bytes(4))

    with {:ok, src_ip} <- get_interface_address(ifname, :inet),
         {:ok, headers, reply} <- make_request(src_ip, nonce, options),
         :ok <- validate_nonce(headers, nonce),
         properties <- build_props(Enum.to_list(reply), []) do
      {:ok, {:internet, properties}}
    else
      {:error, :econnrefused} ->
        {:ok, {:lan, []}}

      {:error, reason} ->
        {:error, reason}

      posix_error when is_atom(posix_error) ->
        {:error, posix_error}
    end
  end

  @spec make_request(:inet.ip_address(), String.t(), Keyword.t()) ::
          {:ok, [{String.t(), String.t()}], map()} | {:error, term()}
  defp make_request(src_ip, nonce, options) do
    url = %{options[:url] | query: "nonce=#{nonce}"}
    request_headers = [{"Content-Type", "application/x-erlang-binary"}]
    request = HTTPClient.create_request(url, src_ip, request_headers)

    case HTTPClient.make_request(request, options[:max_response_size], options[:timeout_millis]) do
      {:ok, {{_version, 200, _status_message}, headers, body}} ->
        Logger.debug(%{term: inspect(body)})
        {:ok, headers, :erlang.binary_to_term(body, [:safe])}

      error ->
        error
    end
  end

  defp build_props([{prop, value} | rest], props) do
    property = {[prop], value}
    build_props(rest, [property | props])
  end

  defp build_props([], props), do: Enum.reverse(props)

  defp validate_nonce([{"X-Nonce", nonce} | _], nonce), do: :ok
  defp validate_nonce([_ | rest], nonce), do: validate_nonce(rest, nonce)
  defp validate_nonce([], _), do: {:error, :nonce}
end
