defmodule VintageNet.Connectivity.HTTPClient do
  @moduledoc """
  Simple HTTP client for testing internet connectivity

  This HTTP client supports so little HTTP that it's easy to reason about how it
  works or doesn't work. This is useful for minimizing the things that can go
  wrong when testing internet connectivity (such as automatically following redirects or returning cached results)
  """

  defmodule Request do
    @moduledoc """
    Wrapper for an HTTP request
    """

    @type t :: %__MODULE__{
            uri: URI.t(),
            headers: [{String.t(), String.t()}],
            method: String.t(),
            opts: [:gen_tcp.connect_option()]
          }

    defstruct uri: %URI{}, headers: [], method: "GET", opts: []

    @doc false
    @spec new(URI.t(), String.t(), [{String.t(), String.t()}], [:gen_tcp.connect_option()]) :: t()
    def new(uri, method, headers, opts) do
      %__MODULE__{uri: uri, method: method, headers: headers, opts: opts}
    end
  end

  @doc "Create a request from the specified IP address"
  @spec create_request(URI.t(), VintageNet.ifname()) :: Request.t()
  def create_request(uri, ifname) do
    Request.new(
      uri,
      "GET",
      [{"User-Agent", "VintageNet/#{version()}"}, {"Host", uri.host}, {"Connection", "close"}],
      [
        :binary,
        packet: :raw,
        active: false
      ] ++ bind_to_device(ifname)
    )
  end

  defp bind_to_device(ifname) do
    case :os.type() do
      {:unix, :linux} -> [bind_to_device: ifname]
      _ -> []
    end
  end

  defp version() do
    Application.spec(:vintage_net, :vsn)
    |> to_string()
  end

  @type preamble :: {String.t(), pos_integer(), String.t()}
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()

  @doc "Execute a request"
  @spec make_request(Request.t(), pos_integer(), pos_integer()) ::
          {:ok, {preamble(), headers(), body()}} | {:error, term()}
  def make_request(%Request{} = request, max_response_size, timeout_millis) do
    fail_after_millis = System.monotonic_time(:millisecond) + timeout_millis

    with {:ok, socket} <-
           :gen_tcp.connect(
             ~c"#{request.uri.host}",
             request.uri.port,
             request.opts,
             timeout_millis
           ),
         :ok <- :gen_tcp.send(socket, request_message(request)),
         {:ok, response} <- receive_response(socket, fail_after_millis, max_response_size, []) do
      parse_response(response)
    end
  end

  @doc false
  @spec parse_response(String.t()) :: {:ok, {preamble(), headers(), body()}}
  def parse_response(body) do
    [preamble | rest] = String.split(String.trim(body), "\r\n")
    [version, response_code, response_string] = String.split(preamble, " ", parts: 3)

    {headers, body} = parse_response_headers(rest, [])
    {:ok, {{version, String.to_integer(response_code), response_string}, headers, body}}
  end

  @doc false
  @spec parse_response_headers(iodata(), [headers()]) :: {headers(), iodata()}
  def parse_response_headers(["" | rest], headers) do
    {Enum.reverse(headers), Enum.join(rest, "\n")}
  end

  def parse_response_headers([header | rest], headers) do
    [key, value] = String.split(header, ":", parts: 2)
    parse_response_headers(rest, [{String.trim(key), String.trim(value)} | headers])
  end

  def parse_response_headers([], headers) do
    {Enum.reverse(headers), ""}
  end

  defp receive_response(socket, fail_after_millis, max_bytes_left, buffer) do
    time_left_millis = fail_after_millis - System.monotonic_time(:millisecond)

    if time_left_millis > 0 and max_bytes_left > 0 do
      case :gen_tcp.recv(socket, 0, time_left_millis) do
        {:ok, data} ->
          receive_response(
            socket,
            fail_after_millis,
            max_bytes_left - byte_size(data),
            [data | buffer]
          )

        {:error, :closed} ->
          :gen_tcp.close(socket)
          {:ok, Enum.reverse(buffer) |> IO.iodata_to_binary()}
      end
    else
      :gen_tcp.close(socket)
      {:error, :timeout}
    end
  end

  defp request_message(request) do
    query = if request.uri.query, do: "?#{request.uri.query}", else: ""

    [
      request.method,
      ?\s,
      request.uri.path,
      query,
      " HTTP/1.1\r\n",
      Enum.map(request.headers, fn {k, v} -> [k, ": ", v, "\r\n"] end),
      "\r\n"
    ]
  end
end
