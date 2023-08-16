defmodule VintageNet.RouteManager do
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
  use GenServer

  alias VintageNet.Interface.NameUtilities
  alias VintageNet.Route
  alias VintageNet.Route.{Calculator, DefaultMetric, InterfaceInfo, IPRoute, Properties}
  require Logger

  @typedoc false
  @type state() :: %{
          interfaces: %{VintageNet.ifname() => InterfaceInfo.t()},
          route_state: Calculator.table_indices(),
          routes: Route.entries(),
          route_metric_fun: Route.route_metric_fun()
        }

  @doc """
  Start the route manager

  Options:

  * `:route_metric_fun` - a 2-arity function that takes a ifname and `VintageNet.Route.InterfaceInfo`
    and returns `VintageNet.Route.metric()`
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
          :inet.ip_address()
        ) ::
          :ok
  def set_route(ifname, ip_subnets, route) do
    GenServer.call(__MODULE__, {:set_route, ifname, ip_subnets, route})
  end

  @doc false
  @spec set_route(
          VintageNet.ifname(),
          [{:inet.ip_address(), VintageNet.prefix_length()}],
          :inet.ip_address(),
          VintageNet.connection_status()
        ) ::
          :ok
  @deprecated "set_route/4 is deprecated. Status parameter is assumed to be at least :lan"
  def set_route(ifname, ip_subnets, route, _status) do
    set_route(ifname, ip_subnets, route)
  end

  @doc """
  Set the connection status on an interface.

  Changing the connection status can re-prioritize routing. The
  specified interface doesn't need to have a default route.
  """
  @spec set_connection_status(
          VintageNet.ifname(),
          VintageNet.connection_status(),
          String.t() | nil
        ) ::
          :ok
  def set_connection_status(ifname, status, why \\ nil) do
    why = why || caller()
    GenServer.call(__MODULE__, {:set_connection_status, ifname, status, why})
  end

  defp caller() do
    {:current_stacktrace, [_info, _caller_fun, _vintage_net_fun, {m, f, a, loc} | _rest]} =
      Process.info(self(), :current_stacktrace)

    "#{m}.#{f}/#{a}(#{inspect(loc)})"
  end

  @doc """
  Clear out the default gateway for an interface.
  """
  @spec clear_route(VintageNet.ifname()) :: :ok
  def clear_route(ifname) do
    GenServer.call(__MODULE__, {:clear_route, ifname})
  end

  @doc """
  Refresh route metrics for all interfaces.
  """
  @spec refresh_route_metrics() :: :ok
  def refresh_route_metrics() do
    GenServer.call(__MODULE__, :refresh_route_metrics)
  end

  ## GenServer

  @impl GenServer
  def init(args) do
    route_metric_fun = args[:route_metric_fun] |> check_compute_metric()

    # Fresh slate
    IPRoute.clear_all_routes()
    IPRoute.clear_all_rules(Calculator.rule_table_index_range())

    state =
      %{
        interfaces: %{},
        route_state: Calculator.init(),
        route_metric_fun: route_metric_fun,
        routes: []
      }
      |> update_route_tables()

    {:ok, state}
  end

  defp check_compute_metric(fun) when is_function(fun, 2), do: fun

  defp check_compute_metric(_other) do
    Logger.error("RouteManager: Expecting :route_metric_fun to be a 2-arity function")
    &DefaultMetric.compute_metric/2
  end

  @impl GenServer
  def handle_call({:set_route, ifname, ip_subnets, default_gateway}, _from, state) do
    if interface_info_changed?(state, ifname, ip_subnets, default_gateway) do
      Logger.info(
        "RouteManager: set_route #{ifname}: IP: #{inspect(ip_subnets)}, GW: #{inspect(default_gateway)}"
      )

      # Mostly keep the status.
      #
      # All changes to the connectivity status need to come
      # from the connectivity checker or reasoning about this gets confusing.
      # Note that we know here that the connectivity state may have changed
      # since either the IP address or default gateway changed. Nonetheless,
      # defer to the connectivity checker to tell us.
      #
      # If we don't know about the interface yet (no route), then it definitely
      # has :lan status so start there.
      status =
        case Map.fetch(state.interfaces, ifname) do
          {:ok, %InterfaceInfo{status: status}} -> status
          _ -> :lan
        end

      ifentry = new_interface_info(ifname, ip_subnets, default_gateway, status)

      new_state =
        put_in(state.interfaces[ifname], ifentry)
        |> update_route_tables()

      {:reply, :ok, new_state}
    else
      Logger.info("RouteManager: set_route #{ifname} ignored since no change.")
      {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_call({:set_connection_status, ifname, status, why}, _from, state) do
    new_state =
      state
      |> update_connection_status(ifname, status, why)

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:clear_route, ifname}, _from, state) do
    if Map.has_key?(state.interfaces, ifname) do
      Logger.info("RouteManager: clear_route #{ifname}")

      # Need to force the property to disconnected since we're removing it from the map.
      PropertyTable.put(VintageNet, ["interface", ifname, "connection"], :disconnected)

      new_state =
        %{state | interfaces: Map.delete(state.interfaces, ifname)}
        |> update_route_tables()

      {:reply, :ok, new_state}
    else
      {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_call(:refresh_route_metrics, _from, state) do
    Logger.info("RouteManager: refresh_route_metrics")
    new_state = update_route_tables(state)
    {:reply, :ok, new_state}
  end

  defp interface_info_changed?(state, ifname, ip_subnets, default_gateway) do
    case Map.fetch(state.interfaces, ifname) do
      {:ok,
       %InterfaceInfo{ip_subnets: ^ip_subnets, default_gateway: ^default_gateway, status: status}}
      when status in [:lan, :internet] ->
        false

      _ ->
        true
    end
  end

  defp new_interface_info(ifname, ip_subnets, default_gateway, status) do
    # The weight parameter prioritizes interfaces of the same type and connectivity.
    # All weights for interfaces of the same type must be different. I.e., we don't
    # leave it to chance which one is used. Also, bandwidth sharing of interfaces
    # can't be accomplished by giving interfaces the same low level priority with
    # how things are set up anyway.
    #
    # It will likely be necessary to expose this to users who have more than one
    # of the same interface type available. For now, lower numbered interfaces
    # have priority. For example, eth0 is used over eth1, etc. The 10 is hardcoded
    # to correspond to the calculation in default_metric.ex.
    weight = rem(NameUtilities.get_instance(ifname), 10)

    %InterfaceInfo{
      interface_type: NameUtilities.to_type(ifname),
      weight: weight,
      ip_subnets: ip_subnets,
      default_gateway: default_gateway,
      status: status
    }
  end

  # Only process routes if the status changes
  defp update_connection_status(state, ifname, new_status, why) do
    case state.interfaces[ifname] do
      nil ->
        Logger.warning(
          "RouteManager: new set_connection_status #{ifname} -> #{inspect(new_status)} (#{why})"
        )

        ifentry = new_interface_info(ifname, [], nil, new_status)

        put_in(state.interfaces[ifname], ifentry)
        |> update_route_tables()

      ifentry ->
        if ifentry.status != new_status do
          Logger.info(
            "RouteManager: set_connection_status #{ifname} -> #{inspect(new_status)} (#{why})"
          )

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
      Calculator.compute(state.route_state, state.interfaces, state.route_metric_fun)

    route_delta = List.myers_difference(state.routes, new_routes)

    # Update Linux's routing tables
    Enum.each(route_delta, &handle_delta/1)

    # Update the global routing properties in the property table
    # NOTE: These next three calls can update zero or more entries
    #       in the property table. There's no notion of atomicity,
    #       so it's possible for listeners to detect inconsistencies.
    #       All orderings are problematic in some scenario. However,
    #       in practice, a user is mostly listening either to the
    #       overall state (which interfaces are available on the device
    #       or whether the device can reach the internet in any way) or
    #       it's specifically interested in one interface.
    Properties.update_available_interfaces(new_routes)
    Properties.update_best_connection(state.interfaces)
    Properties.update_connection_status(state.interfaces)

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
    IPRoute.add_default_route(ifname, default_gateway, metric, table_index)
    |> warn_on_error("add_default_route")
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
    Logger.warning("route_manager(#{label}): ignoring failure #{inspect(reason)}")
  end
end
