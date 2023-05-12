defmodule VintageNet.Connectivity.InternetChecker do
  @moduledoc """
  This GenServer monitors a network interface for Internet connectivity

  Internet connectivity is determined by reachability to an IP address.
  If that address is reachable then other this updates a property to
  reflect that. Otherwise, the network interface is assumed to merely
  have LAN connectivity if it's up.
  """
  use GenServer

  alias VintageNet.Connectivity.{CheckLogic, HostList, Inspector, TCPPing}
  alias VintageNet.RouteManager
  require Logger

  @typedoc false
  @type state() :: %{
          ifname: VintageNet.ifname(),
          configured_hosts: [{VintageNet.any_ip_address(), non_neg_integer()}],
          ping_list: [{:inet.ip_address(), non_neg_integer()}],
          check_logic: CheckLogic.state(),
          inspector: Inspector.cache(),
          status: Inspector.status()
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
      configured_hosts: HostList.load(),
      ping_list: [],
      check_logic: CheckLogic.init(connectivity),
      inspector: %{},
      status: :unknown
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

    {:noreply, new_state, new_state.check_logic.interval}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    new_state = state |> check_connectivity() |> report_connectivity("timeout")

    {:noreply, new_state, new_state.check_logic.interval}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, false, _meta},
        %{ifname: ifname} = state
      ) do
    new_state = state |> ifdown() |> report_connectivity("ifdown")

    {:noreply, new_state, new_state.check_logic.interval}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, true, _meta},
        %{ifname: ifname} = state
      ) do
    new_state = state |> ifup() |> report_connectivity("ifup")

    {:noreply, new_state, new_state.check_logic.interval}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, nil, _meta},
        %{ifname: ifname} = state
      ) do
    # The interface was completely removed!
    new_state = state |> ifdown() |> report_connectivity("removed!")
    {:noreply, new_state, new_state.check_logic.interval}
  end

  defp ifdown(state) do
    %{state | check_logic: CheckLogic.ifdown(state.check_logic)}
  end

  defp ifup(state) do
    %{state | check_logic: CheckLogic.ifup(state.check_logic)}
  end

  defp check_connectivity(state) do
    # Steps
    # 1. Reset status to unknown
    # 2. See if we can determine internet-connectivity via TCP stats
    # 3. If still unknown, refresh the ping list
    # 4. If still unknown, ping. This step is definitive.
    # 5. Record whether there's internet
    state
    |> reset_status()
    |> check_inspector()
    |> reload_ping_list()
    |> ping_if_unknown()
    |> update_check_logic()
  end

  defp reset_status(state) do
    %{state | status: :unknown}
  end

  defp check_inspector(state) do
    {status, new_cache} = Inspector.check_internet(state.ifname, state.inspector)
    %{state | status: status, inspector: new_cache}
  end

  defp reload_ping_list(%{status: :unknown, ping_list: []} = state) do
    # Create the ping list and filter out anything that's on the same LAN since
    # pinging those addresses would be inconclusive.
    ping_list =
      HostList.create_ping_list(state.configured_hosts)
      |> Enum.filter(&Inspector.routed_address?(state.ifname, &1))

    %{state | ping_list: ping_list}
  end

  defp reload_ping_list(state), do: state

  defp ping_if_unknown(%{status: :unknown, ping_list: [who | rest]} = state) do
    case TCPPing.ping(state.ifname, who) do
      :ok -> %{state | status: :internet}
      _error -> %{state | status: :no_internet, ping_list: rest}
    end
  end

  defp ping_if_unknown(%{status: :unknown, ping_list: []} = state) do
    # Ping list being empty is due to the user only providing hostnames and
    # DNS resolution not working.
    %{state | status: :no_internet}
  end

  defp ping_if_unknown(state), do: state

  defp update_check_logic(%{status: :internet} = state) do
    %{state | check_logic: CheckLogic.check_succeeded(state.check_logic)}
  end

  defp update_check_logic(%{status: :no_internet} = state) do
    %{state | check_logic: CheckLogic.check_failed(state.check_logic)}
  end

  defp report_connectivity(state, why) do
    # It's desirable to set these even if redundant since the checks in this
    # modules are authoritative. I.e., the internet isn't connected unless we
    # declare it detected.The following call
    # will optimize out redundant updates if they really are redundant.
    RouteManager.set_connection_status(state.ifname, state.check_logic.connectivity, why)
    state
  end

  defp lower_up_property(ifname) do
    ["interface", ifname, "lower_up"]
  end
end
