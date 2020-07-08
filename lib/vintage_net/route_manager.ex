defmodule VintageNet.RouteManager do
  use GenServer
  require Logger

  alias VintageNet.Interface.Classification
  alias VintageNet.Route.{Calculator, InterfaceInfo, IPRoute, Properties}

  @moduledoc """
  This module manages the default route.

  Devices with more than one network interface may have more than one
  way of reaching the Internet. The routing table decides which interface
  an IP packet should use by looking at the "default route" entries.
  One interface is chosen.

  Since not all interfaces are equal, we'd like Linux to pick the
  fastest and lowest latency one. for example, one could
  prefer wired Ethernet over WiFi and prefer WiFi over a cellular
  connection. This module lets you specify an ordering for interfaces
  and sets up the routes based on this ordering.

  This module also handles networking failures. One failure that
  Linux can't figure out on its own is whether an interface can
  reach the Internet. Internet reachability is handled elsewhere
  like in the `ConnectivityChecker` module. This module should be
  told reachability status so that it can properly order default
  routes so that the best reachable interface is used.

  IMPORTANT: This module uses priority-based routing. Make sure the
  following kernel options are enabled:

  ```text
  CONFIG_IP_ADVANCED_ROUTER=y
  CONFIG_IP_MULTIPLE_TABLES=y
  ```
  """

  defmodule State do
    @moduledoc false

    defstruct prioritization: nil, interfaces: nil, route_state: nil, routes: []
  end

  @doc """
  Start the route manager.
  """
  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Stop the route manager.
  """
  @spec stop() :: :ok
  def stop() do
    GenServer.stop(__MODULE__)
  end

  @doc """
  Set the default route for an interface.

  This replaces any existing routes on that interface
  """
  @spec set_route(
          VintageNet.ifname(),
          [{:inet.ip_address(), VintageNet.prefix_length()}],
          :inet.ip_address(),
          Classification.connection_status()
        ) ::
          :ok
  def set_route(ifname, ip_subnets, route, status \\ :lan) do
    GenServer.call(__MODULE__, {:set_route, ifname, ip_subnets, route, status})
  end

  @doc """
  Set the connection status on an interface.

  Changing the connection status can re-prioritize routing. The
  specified interface doesn't need to have a default route.
  """
  @spec set_connection_status(VintageNet.ifname(), Classification.connection_status()) :: :ok
  def set_connection_status(ifname, status) do
    GenServer.call(__MODULE__, {:set_connection_status, ifname, status})
  end

  @doc """
  Clear out the default gateway for an interface.
  """
  @spec clear_route(VintageNet.ifname()) :: :ok
  def clear_route(ifname) do
    GenServer.call(__MODULE__, {:clear_route, ifname})
  end

  @doc """
  Set the order that default gateways should be used

  The list is ordered from highest priority to lowest
  """
  @spec set_prioritization([Classification.prioritization()]) :: :ok
  def set_prioritization(priorities) do
    GenServer.call(__MODULE__, {:set_prioritization, priorities})
  end

  ## GenServer

  @impl GenServer
  def init(_args) do
    # Fresh slate
    IPRoute.clear_all_routes()
    IPRoute.clear_all_rules(Calculator.rule_table_index_range())

    state =
      %State{
        prioritization: Classification.default_prioritization(),
        interfaces: %{},
        route_state: Calculator.init()
      }
      |> update_route_tables()

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:set_route, ifname, ip_subnets, default_gateway, status}, _from, state) do
    Logger.info("RouteManager: set_route #{ifname} -> #{inspect(status)}")

    # The weight parameter prioritizes interfaces of the same type and connectivity.
    # All weights for interfaces of the same time must be different. I.e., we don't
    # leave it to chance which one is used. Also, bandwidth sharing of interfaces
    # can't be accomplished by giving interfaces the same low level priority with
    # how things are set up anyway.
    #
    # It will likely be necessary to expose this to users who have more than one
    # of the same interface type available. For now, lower numbered interfaces
    # have priority. For example, eth0 is used over eth1, etc. The 10 is hardcoded
    # to correspond to the calculation in classification.ex.
    weight = rem(Classification.to_instance(ifname), 10)

    ifentry = %InterfaceInfo{
      interface_type: Classification.to_type(ifname),
      weight: weight,
      ip_subnets: ip_subnets,
      default_gateway: default_gateway,
      status: status
    }

    new_state =
      put_in(state.interfaces[ifname], ifentry)
      |> update_route_tables()

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_connection_status, ifname, status}, _from, state) do
    new_state =
      state
      |> update_connection_status(ifname, status)

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:clear_route, ifname}, _from, state) do
    new_state =
      if Map.has_key?(state.interfaces, ifname) do
        Logger.info("RouteManager: clear_route #{ifname}")

        %{state | interfaces: Map.delete(state.interfaces, ifname)}
        |> update_route_tables()
      else
        state
      end

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_prioritization, priorities}, _from, state) do
    new_state =
      state
      |> Map.put(:prioritization, priorities)
      |> update_route_tables()

    {:reply, :ok, new_state}
  end

  # Only process routes if the status changes
  defp update_connection_status(
         %State{interfaces: interfaces} = state,
         ifname,
         new_status
       ) do
    case interfaces[ifname] do
      nil ->
        state

      ifentry ->
        if ifentry.status != new_status do
          Logger.info("RouteManager: set_connection_status #{ifname} -> #{inspect(new_status)}")

          put_in(state.interfaces[ifname].status, new_status)
          |> update_route_tables()
        else
          state
        end
    end
  end

  defp update_route_tables(state) do
    # See what changed and then run it.
    {new_route_state, new_routes} =
      Calculator.compute(state.route_state, state.interfaces, state.prioritization)

    route_delta = List.myers_difference(state.routes, new_routes)

    # Update Linux's routing tables
    Enum.each(route_delta, &handle_delta/1)

    # Update the global routing properties in the property table
    Properties.update_available_interfaces(new_routes)
    Properties.update_best_connection(state.interfaces)

    %{state | route_state: new_route_state, routes: new_routes}
  end

  defp handle_delta({:eq, _anything}), do: :ok

  defp handle_delta({:del, deletes}) do
    Enum.each(deletes, &handle_delete/1)
  end

  defp handle_delta({:ins, inserts}) do
    Enum.each(inserts, &handle_insert/1)
  end

  defp handle_delete({:default_route, ifname, _default_gateway, _metric, table_index}) do
    IPRoute.clear_a_route(ifname, table_index)
    |> warn_on_error("clear_a_route")
  end

  defp handle_delete({:local_route, ifname, address, subnet_bits, metric, table_index}) do
    IPRoute.clear_a_local_route(ifname, address, subnet_bits, metric, table_index)
    |> warn_on_error("clear_a_local_route")
  end

  defp handle_delete({:rule, table_index, _address}) do
    IPRoute.clear_a_rule(table_index)
    |> warn_on_error("clear_a_rule")
  end

  defp handle_insert({:default_route, ifname, default_gateway, metric, table_index}) do
    :ok = IPRoute.add_default_route(ifname, default_gateway, metric, table_index)
  end

  defp handle_insert({:rule, table_index, address}) do
    :ok = IPRoute.add_rule(address, table_index)
  end

  defp handle_insert({:local_route, ifname, address, subnet_bits, metric, table_index}) do
    if table_index == :main do
      # HACK: Delete automatically created local routes that have a 0 metric
      _ = IPRoute.clear_a_local_route(ifname, address, subnet_bits, 0, :main)
      :ok
    end

    :ok = IPRoute.add_local_route(ifname, address, subnet_bits, metric, table_index)
  end

  defp warn_on_error(:ok, _label), do: :ok

  defp warn_on_error({:error, reason}, label) do
    Logger.warn("route_manager(#{label}): ignoring failure #{inspect(reason)}")
  end
end
