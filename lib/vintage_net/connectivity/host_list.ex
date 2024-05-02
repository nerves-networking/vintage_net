defmodule VintageNet.Connectivity.HostList do
  @moduledoc false

  import Record, only: [defrecord: 2]

  require Logger

  @typedoc """
  IP address in tuple form or a hostname
  """
  @type ip_or_hostname() :: :inet.ip_address() | String.t()

  @type option :: {:host, ip_or_hostname()} | {:port, 1..65535}
  @type options :: [option]

  @type entry :: {:tcp_ping | :ssl_ping, options}

  @type hostent() :: record(:hostent, [])

  defrecord :hostent, Record.extract(:hostent, from_lib: "kernel/include/inet.hrl")

  @default_list [{:tcp_ping, host: {1, 1, 1, 1}, port: 53}]

  @doc """
  Load the internet host list from the application environment

  This function performs basic checks on the list and tries to
  help users on easy mistakes.
  """
  @spec load(keyword()) :: [entry]
  def load(config \\ Application.get_all_env(:vintage_net)) do
    config_list = internet_host_list(config) ++ legacy_internet_host(config)

    hosts =
      config_list
      |> Enum.map(&normalize/1)
      |> Enum.reject(fn x -> x == :error end)

    if hosts == [] do
      Logger.warning("VintageNet: empty or invalid `:internet_host_list` so using defaults")
      @default_list
    else
      hosts
    end
  end

  defp internet_host_list(config) do
    case config[:internet_host_list] do
      host_list when is_list(host_list) ->
        host_list

      _ ->
        Logger.warning("VintageNet: :internet_host_list must be a list")
        []
    end
  end

  defp legacy_internet_host(config) do
    case config[:internet_host] do
      nil ->
        []

      host ->
        Logger.warning(
          "VintageNet: :internet_host key is deprecated. Replace with `internet_host_list: [{:tcp_ping, host: #{inspect(host)}, port: 80}]`"
        )

        [{:tcp_ping, host: host, port: 80}]
    end
  end

  defp normalize({kind, opts}) when kind in [:tcp_ping, :ssl_ping] do
    with {:ok, host} <- Keyword.fetch(opts, :host),
         {:ok, port} when port > 0 and port < 65535 <- Keyword.fetch(opts, :port) do
      case VintageNet.IP.ip_to_tuple(host) do
        {:ok, host_as_tuple} -> {kind, host: host_as_tuple, port: port}
        # Likely a domain name
        {:error, _} when is_binary(host) -> {kind, host: host, port: port}
        _ -> :error
      end
    else
      _ -> :error
    end
  end

  defp normalize({host, port}) when port > 0 and port < 65535 do
    # handles legacy list entries, converting them to tcp_ping by default
    normalize({:tcp_ping, host: host, port: port})
  end

  defp normalize(_), do: :error

  @doc """
  Resolve any unresolved host names and generate a list of hosts to ping

  This returns at most 3 hosts to try at a time. If they all fail, this
  should be called again to get another set. This involves DNS, so the
  call can block.
  """
  @spec create_ping_list([entry]) :: [entry()]
  def create_ping_list(hosts) do
    hosts
    |> Enum.flat_map(&resolve_tcp_ping/1)
    |> Enum.uniq()
    |> Enum.shuffle()
    |> Enum.take(3)
  end

  defp resolve_tcp_ping({:tcp_ping, opts} = tcp_ping_entry) do
    port = Keyword.fetch!(opts, :port)

    case Keyword.fetch!(opts, :host) do
      ip when is_tuple(ip) ->
        [tcp_ping_entry]

      host when is_binary(host) ->
        case :inet.gethostbyname(String.to_charlist(host)) do
          {:ok, hostent(h_addr_list: addresses)} ->
            for address <- addresses, do: {:tcp_ping, host: address, port: port}

          _error ->
            # DNS not working, so the internet is not working enough
            # to consider this host
            []
        end
    end
  end

  defp resolve_tcp_ping({:ssl_ping, _opts} = ssl_ping_entry) do
    # don't resolve SSL addresses since the hostname is part of how SSL functions
    [ssl_ping_entry]
  end
end
