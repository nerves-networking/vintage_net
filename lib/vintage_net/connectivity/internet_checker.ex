defmodule VintageNet.Connectivity.InternetChecker do
  @moduledoc """
  This GenServer monitors a network interface for Internet connectivity

  Internet connectivity is determined by reachability to an IP address.
  If that address is reachable then other this updates a property to
  reflect that. Otherwise, the network interface is assumed to merely
  have LAN connectivity if it's up.
  """
  use GenServer

  alias VintageNet.Connectivity.{CheckLogic, Inspector, TCPPing}
  alias VintageNet.RouteManager
  require Logger

  @typedoc false
  @type state() :: %{
          ifname: VintageNet.ifname(),
          hosts: [{VintageNet.any_ip_address(), non_neg_integer()}],
          status: CheckLogic.state(),
          inspector: Inspector.cache()
        }

  @doc """
  Start the connectivity checker GenServer
  """
  @spec start_link(VintageNet.ifname()) :: GenServer.on_start()
  def start_link(ifname) do
    GenServer.start_link(__MODULE__, ifname)
  end

  @impl GenServer
  def init(ifname) do
    connectivity = VintageNet.get(["interface", ifname, "connection"])

    state = %{
      ifname: ifname,
      hosts: get_internet_host_list(),
      status: CheckLogic.init(connectivity),
      inspector: %{}
    }

    {:ok, state, {:continue, :continue}}
  end

  @impl GenServer
  def handle_continue(:continue, %{ifname: ifname} = state) do
    VintageNet.subscribe(lower_up_property(ifname))

    # Always run ifup and ifdown depending on the interface even
    # if it's redundant. There may have been a crash and this will
    # get our connectivity status back in sync.
    new_state =
      if VintageNet.get(lower_up_property(ifname)) do
        state |> ifup() |> report_connectivity("ifup")
      else
        state |> ifdown() |> report_connectivity("ifdown")
      end

    {:noreply, new_state, new_state.status.interval}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    new_state = state |> check_connectivity() |> report_connectivity("timeout")

    {:noreply, new_state, new_state.status.interval}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, false, _meta},
        %{ifname: ifname} = state
      ) do
    new_state = state |> ifdown() |> report_connectivity("ifdown")

    {:noreply, new_state, new_state.status.interval}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, true, _meta},
        %{ifname: ifname} = state
      ) do
    new_state = state |> ifup() |> report_connectivity("ifup")

    {:noreply, new_state, new_state.status.interval}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, nil, _meta},
        %{ifname: ifname} = state
      ) do
    # The interface was completely removed!
    new_state = state |> ifdown() |> report_connectivity("removed!")
    {:noreply, new_state, new_state.status.interval}
  end

  defp ifdown(state) do
    %{state | status: CheckLogic.ifdown(state.status)}
  end

  defp ifup(state) do
    %{state | status: CheckLogic.ifup(state.status)}
  end

  defp check_connectivity(state) do
    {status, new_cache} = Inspector.check_internet(state.ifname, state.inspector)

    if status == :available or TCPPing.ping(state.ifname, hd(state.hosts)) == :ok do
      %{state | status: CheckLogic.check_succeeded(state.status), inspector: new_cache}
    else
      %{
        state
        | status: CheckLogic.check_failed(state.status),
          hosts: rotate_list(state.hosts),
          inspector: new_cache
      }
    end
  end

  defp report_connectivity(state, why) do
    # It's desirable to set these even if redundant since the checks in this
    # modules are authoritative. I.e., the internet isn't connected unless we
    # declare it detected.The following call
    # will optimize out redundant updates if they really are redundant.
    RouteManager.set_connection_status(state.ifname, state.status.connectivity, why)
    state
  end

  defp lower_up_property(ifname) do
    ["interface", ifname, "lower_up"]
  end

  # Rotate a list left
  @doc false
  @spec rotate_list(list()) :: list()
  def rotate_list([]), do: []
  def rotate_list(hosts), do: tl(hosts) ++ [hd(hosts)]

  defp get_internet_host_list() do
    hosts = legacy_internet_host() ++ Application.get_env(:vintage_net, :internet_host_list)
    good_hosts = Enum.flat_map(hosts, &normalize_internet_host/1)

    if good_hosts == [] do
      Logger.warn("VintageNet: `:internet_host_list` is invalid. Using defaults")
      [{1, 1, 1, 1}, 80]
    else
      good_hosts
    end
  end

  defp legacy_internet_host() do
    case Application.get_env(:vintage_net, :internet_host) do
      nil ->
        []

      host ->
        Logger.warn(
          "VintageNet: Legacy :internet_host key is in use. Please change this to `internet_host_list: [{#{inspect(host)}, 80}]."
        )

        [{host, 80}]
    end
  end

  defp normalize_internet_host({host, port}) when port > 0 and port < 65536 do
    case VintageNet.IP.ip_to_tuple(host) do
      {:ok, host_as_tuple} -> [{host_as_tuple, port}]
      _anything_else -> []
    end
  end

  defp normalize_internet_host(other) do
    Logger.warn("VintageNet: Dropping invalid Internet destination (#{inspect(other)})")
  end
end
