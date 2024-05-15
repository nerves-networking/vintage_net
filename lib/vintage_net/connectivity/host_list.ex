defmodule VintageNet.Connectivity.HostList do
  @moduledoc false

  alias VintageNet.Connectivity.TCPPing
  alias VintageNet.Connectivity.WebRequest
  require Logger

  @typedoc """
  IP address in tuple form or a hostname
  """
  @type ip_or_hostname() :: :inet.ip_address() | String.t()

  @type option() :: {:host, ip_or_hostname()} | {:port, 1..65535}
  @type options() :: [option()]

  @type entry() :: {:tcp_ping | :ssl_ping | module(), options()}

  @default_list [{TCPPing, host: {1, 1, 1, 1}, port: 53}]

  @doc """
  Load the internet host list from the application environment

  This function performs basic checks on the list and tries to
  help users on easy mistakes.
  """
  @spec load(keyword()) :: [entry()]
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

        [{TCPPing, host: host, port: 80}]
    end
  end

  defp normalize({:tcp_ping, opts}), do: normalize({TCPPing, opts})
  defp normalize({:web_request, opts}), do: normalize({WebRequest, opts})

  defp normalize({module, opts} = spec) when is_atom(module) and is_list(opts) do
    module.normalize(spec)
  catch
    _, _ -> :error
  end

  defp normalize({host, port}) when port > 0 and port < 65535 do
    # handles legacy list entries, converting them to tcp_ping by default
    normalize({TCPPing, host: host, port: port})
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
    |> Enum.flat_map(&expand_ping_list/1)
    |> Enum.uniq()
    |> Enum.shuffle()
    |> Enum.take(3)
  end

  defp expand_ping_list({module, _opts} = spec) do
    case module.expand(spec) do
      result when is_list(result) -> result
      _ -> []
    end
  catch
    _, _ -> []
  end
end
