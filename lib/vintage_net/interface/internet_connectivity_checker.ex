defmodule VintageNet.Interface.InternetConnectivityChecker do
  use GenServer
  require Logger

  alias VintageNet.Interface.{Classification, InternetTester}
  alias VintageNet.RouteManager

  @moduledoc """
  This GenServer monitors a network interface for Internet connectivity

  Internet connectivity is determined by reachability to an IP address.
  If that address is reachable then other this updates a property to
  reflect that. Otherwise, the network interface is assumed to merely
  have LAN connectivity if it's up.
  """
  @min_interval 500
  @max_interval 30_000
  @max_fails_in_a_row 3

  @typep state() :: %{
           ifname: VintageNet.ifname(),
           hosts: [{VintageNet.any_ip_address(), non_neg_integer()}],
           strikes: non_neg_integer(),
           interval: non_neg_integer(),
           connectivity: Classification.connection_status()
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
    # Handle GenServer restarts when internet-connected. If internet connected,
    # then start the strike count over at zero since who knows where things were
    # at and that way a first strike doesn't bounce the status.
    connectivity = VintageNet.get(["interface", ifname, "connection"])
    initial_strikes = if connectivity == :internet, do: 0, else: @max_fails_in_a_row

    state = %{
      ifname: ifname,
      hosts: get_internet_host_list(),
      strikes: initial_strikes,
      interval: @min_interval,
      connectivity: connectivity
    }

    {:ok, state, {:continue, :continue}}
  end

  @impl GenServer
  def handle_continue(:continue, %{ifname: ifname} = state) do
    VintageNet.subscribe(lower_up_property(ifname))

    new_state =
      if VintageNet.get(lower_up_property(ifname)) do
        check_connectivity(state)
      else
        state |> ifdown() |> report_connectivity()
      end

    {:noreply, new_state, new_state.interval}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    new_state = check_connectivity(state)

    {:noreply, new_state, new_state.interval}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, false, _meta},
        %{ifname: ifname} = state
      ) do
    new_state = state |> ifdown() |> report_connectivity()

    {:noreply, new_state}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, true, _meta},
        %{ifname: ifname} = state
      ) do
    new_state = state |> ifup() |> report_connectivity()

    {:noreply, new_state, @min_interval}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, nil, _meta},
        %{ifname: ifname} = state
      ) do
    # The interface was completely removed!
    new_state = state |> ifdown() |> report_connectivity()
    {:noreply, new_state}
  end

  defp ifdown(state) do
    # Physical layer is down. Don't poll for connectivity since it won't happen.
    %{state | connectivity: :disconnected, interval: :infinity}
  end

  defp ifup(state) do
    # Physical layer is up. Optimistically assume that the LAN is accessible and
    # start polling again after a short delay
    %{state | connectivity: :lan, interval: @min_interval}
  end

  defp check_connectivity(state) do
    ping_result = InternetTester.ping(state.ifname, hd(state.hosts))

    state
    |> update_state_from_ping(ping_result)
    |> report_connectivity()
    |> compute_next_interval()
  end

  # Public for unit test purposes
  @doc false
  @spec update_state_from_ping(state(), :ok | {:error, InternetTester.ping_error_reason()}) ::
          state()
  def update_state_from_ping(state, :ok) do
    # Success - reset the number of strikes to stay in Internet mode
    # even if there are hiccups.
    %{state | connectivity: :internet, strikes: 0}
  end

  def update_state_from_ping(state, {:error, :if_not_found}) do
    %{state | connectivity: :disconnected, strikes: @max_fails_in_a_row}
  end

  def update_state_from_ping(state, {:error, :no_ipv4_address}) do
    %{state | connectivity: :lan, strikes: @max_fails_in_a_row}
  end

  def update_state_from_ping(%{connectivity: :internet} = state, {:error, reason}) do
    strikes = state.strikes + 1

    if strikes < @max_fails_in_a_row do
      Logger.debug(
        "#{state.ifname}: Internet check failed to #{inspect(hd(state.hosts))} (#{inspect(reason)}): #{strikes}/#{@max_fails_in_a_row} strikes"
      )

      %{state | strikes: strikes, hosts: rotate_list(state.hosts)}
    else
      Logger.debug("#{state.ifname}: Internet unreachable: (#{inspect(reason)})")
      %{state | connectivity: :lan, strikes: @max_fails_in_a_row, hosts: rotate_list(state.hosts)}
    end
  end

  def update_state_from_ping(state, {:error, _reason}) do
    # Final case where the internet wasn't reachable and it wasn't reachable before this.
    # Rotate the hosts to check and maybe we'll get lucky next time.
    %{state | hosts: rotate_list(state.hosts)}
  end

  defp report_connectivity(%{ifname: ifname, connectivity: connectivity} = state) do
    # It's desirable to set these even if redundant since the checks in this
    # modules are authoritative. I.e., the internet isn't connected unless we
    # declare it detected. Other modules can reset the connection to :lan
    # if, for example, a new IP address gets set by DHCP. The following call
    # will optimize out redundant updates if they really are redundant.
    RouteManager.set_connection_status(ifname, connectivity)
    state
  end

  defp lower_up_property(ifname) do
    ["interface", ifname, "lower_up"]
  end

  # Public for unit test purposes
  @doc false
  @spec compute_next_interval(state()) :: state()
  def compute_next_interval(state) do
    %{state | interval: next_interval(state.connectivity, state.interval, state.strikes)}
  end

  # Public for unit test purposes
  @doc false
  @spec next_interval(Classification.connection_status(), non_neg_integer(), non_neg_integer()) ::
          non_neg_integer()
  def next_interval(connection, interval, strikes)

  # If pings work, then wait the max interval before checking again
  def next_interval(:internet, _interval, 0), do: @max_interval

  # If a ping fails, retry, but don't wait as long as when everything is working
  def next_interval(:internet, _interval, strikes) do
    max(@min_interval, div(@max_interval, strikes + 1))
  end

  # Back off of checks if they're not working
  def next_interval(:lan, interval, _strikes) do
    min(interval * 2, @max_interval)
  end

  # Wait for interface up notification before polling again
  def next_interval(:disconnected, _interval, _strikes), do: :infinity

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
