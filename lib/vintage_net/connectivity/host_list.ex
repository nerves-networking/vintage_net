defmodule VintageNet.Connectivity.HostList do
  @moduledoc false

  import Record, only: [defrecord: 2]

  require Logger

  @typedoc """
  IP address in tuple form or a hostname
  """
  @type ip_or_hostname() :: :inet.ip_address() | String.t()

  @type name_port() :: {ip_or_hostname(), 1..65535}
  @type ip_port() :: {:inet.ip_address(), 1..65535}

  @type hostent() :: record(:hostent, [])

  defrecord :hostent, Record.extract(:hostent, from_lib: "kernel/include/inet.hrl")

  @doc """
  Load the internet host list from the application environment

  This function performs basic checks on the list and tries to
  help users on easy mistakes.
  """
  @spec load(keyword()) :: [name_port()]
  def load(config \\ Application.get_all_env(:vintage_net)) do
    config_list = internet_host_list(config) ++ legacy_internet_host(config)

    hosts =
      config_list
      |> Enum.map(&normalize/1)
      |> Enum.reject(fn x -> x == :error end)

    if hosts == [] do
      Logger.warning("VintageNet: empty or invalid `:internet_host_list` so using defaults")
      [{{1, 1, 1, 1}, 80}]
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
          "VintageNet: :internet_host key is deprecated. Replace with `internet_host_list: [{#{inspect(host)}, 80}]`"
        )

        [{host, 80}]
    end
  end

  defp normalize({host, port}) when port > 0 and port < 65535 do
    case VintageNet.IP.ip_to_tuple(host) do
      {:ok, host_as_tuple} -> {host_as_tuple, port}
      # Likely a domain name
      {:error, _} when is_binary(host) -> {host, port}
      _ -> :error
    end
  end

  defp normalize(_), do: :error

  @doc """
  Resolve any unresolved host names and generate a list of hosts to ping

  This returns at most 3 hosts to try at a time. If they all fail, this
  should be called again to get another set. This involves DNS, so the
  call can block.
  """
  @spec create_ping_list([name_port()]) :: [ip_port()]
  def create_ping_list(hosts) do
    hosts
    |> Enum.flat_map(&resolve/1)
    |> Enum.uniq()
    |> Enum.shuffle()
    |> Enum.take(3)
  end

  defp resolve({ip, _port} = ip_port) when is_tuple(ip) do
    [ip_port]
  end

  defp resolve({name, port}) when is_binary(name) do
    # Only consider IPv4 for now
    case :inet.gethostbyname(String.to_charlist(name)) do
      {:ok, hostent(h_addr_list: addresses)} ->
        for address <- addresses, do: {address, port}

      _error ->
        # DNS not working, so the internet is not working enough
        # to consider this host
        []
    end
  end
end
