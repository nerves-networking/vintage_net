defmodule VintageNet.Connectivity.HTTPClient do
  @moduledoc """
  Very simple HTTP client that only supports GET requests

  Used for testing connectivity. DO NOT USE for general
  HTTP request needs. 
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

  @doc "Create a request from the specified ip address"
  @spec create_request(URI.t(), :inet.ip_address()) :: Request.t()
  def create_request(uri, src_ip) do
    Request.new(uri, "GET", [{"User-Agent", "VintageNet vintage_net v0.0.1"}], [
      :binary,
      ip: src_ip,
      packet: :raw,
      active: false
    ])
  end

  @type preamble :: {String.t(), pos_integer(), String.t()}
  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()
  @spec make_request(Request.t(), pos_integer()) ::
          {:ok, {preamble(), headers(), body()}} | {:error, term()}

  @doc "Execute a request"
  def make_request(%Request{} = request, timeout) do
    with {:ok, socket} <-
           :gen_tcp.connect(~c"#{request.uri.host}", request.uri.port, request.opts, timeout),
         :ok <- :gen_tcp.send(socket, request_body(request)),
         {:ok, response} <- receive_response(socket, timeout, []) do
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
  @spec parse_response_headers([String.t()], [headers()]) :: headers()
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

  @spec receive_response(:gen_tcp.socket(), number(), [String.t()]) :: {:ok, String.t()} | {:error, term()}
  defp receive_response(socket, timeout, _buffer) when timeout <= 0 do
    :gen_tcp.close(socket)
    {:error, :timeout}
  end

  defp receive_response(socket, timeout, buffer) do
    start = :os.system_time(:millisecond)

    case :gen_tcp.recv(socket, 0, timeout) do
      {:ok, data} ->
        elapsed = :os.system_time(:millisecond) - start
        receive_response(socket, timeout - elapsed, [data | buffer])

      {:error, :closed} ->
        :gen_tcp.close(socket)
        {:ok, Enum.reverse(buffer) |> IO.iodata_to_binary()}
    end
  end

  @spec request_body(Request.t()) :: String.t()
  defp request_body(request) do
    query = if request.uri.query, do: "?#{request.uri.query}", else: ""

    """
    #{request.method} #{request.uri.path}#{query} HTTP/1.1\r
    Host: #{request.uri.host}\r
    Connection: close\r
    #{request_headers(request)}
    \r
    """
  end

  @spec request_headers(Request.t()) :: String.t()
  defp request_headers(request) do
    Enum.reduce(request.headers, "", fn {key, value}, buffer ->
      buffer <> "#{key}: #{value}\r\n"
    end)
  end
end
