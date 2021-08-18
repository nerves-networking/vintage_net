defmodule VintageNet.Route.Calculator do
  @moduledoc """
  This module computes the desired routing table contents

  It's used by the RouteManager to update the Linux routing tables when interfaces
  come online or change state. See the RouteManager docs for a discussion of how
  routes are configured.

  The functions in this module have no side effects so that it's easier
  to test that routing scenarios result in correct Linux routing table
  configurations.
  """

  alias VintageNet.Route
  alias VintageNet.Route.InterfaceInfo

  @type table_indices :: %{VintageNet.ifname() => Route.table_index()}

  @type interface_infos :: %{VintageNet.ifname() => InterfaceInfo.t()}

  @doc """
  Initialize state carried between calculations
  """
  @spec init() :: table_indices()
  def init() do
    %{}
  end

  @doc """
  Return the table indices used for routing based on source IP.
  """
  @spec rule_table_index_range() :: Range.t()
  def rule_table_index_range() do
    max_index = 100 + VintageNet.max_interface_count() - 1
    100..max_index
  end

  @doc """
  Compute a Linux routing table configuration

  The entries are ordered so that List.myers_difference/2 can be used to
  minimize the routing table changes.
  """
  @spec compute(table_indices(), interface_infos(), Route.route_metric_fun()) ::
          {table_indices(), Route.entries()}
  def compute(table_indices, infos, route_metric_fun) do
    {new_table_indices, entries} =
      Enum.reduce(infos, {table_indices, []}, &make_entries(&1, &2, route_metric_fun))

    sorted_entries = Enum.sort(entries, &sort/2)

    {new_table_indices, sorted_entries}
  end

  # Sort order
  #
  # 1. Rules
  # 2. Local routes
  # 3. Default routes
  #
  # The most important part is that local routes get created before default
  # routes.  Linux disallows default routes that can't be supported and the
  # local routes are needed for that.
  defp sort_priority(:rule), do: 0
  defp sort_priority(:local_route), do: 1
  defp sort_priority(:default_route), do: 2

  defp sort(a, b) when elem(a, 0) == elem(b, 0) do
    a <= b
  end

  defp sort(a, b) do
    priority_a = elem(a, 0) |> sort_priority()
    priority_b = elem(b, 0) |> sort_priority()
    priority_a <= priority_b
  end

  defp make_entries({ifname, info}, {table_indices, entries}, route_metric_fun) do
    {new_table_indices, table_index} = get_table_index(ifname, table_indices)
    metric = route_metric_fun.(ifname, info)

    new_entries = routing_table_entries(metric, ifname, table_index, info)

    {new_table_indices, new_entries ++ entries}
  end

  defp routing_table_entries(:disabled, _ifname, _table_index, _info) do
    []
  end

  defp routing_table_entries(metric, ifname, table_index, info) do
    # Every packet with a source IP address of this interface should use the
    # routing table "table_index" instead of the "main" one. That lets users
    # communicate bidirectionally on interfaces that wouldn't be used by default.
    # For example, consider a WiFi/Ethernet case: without this, responses to a
    # TCP connection initiated over WiFi could be sent via Ethernet since
    # Ethernet is generally preferred over WiFi. However, that would be strange
    # to have packets received over WiFi be responded to via Ethernet.
    rules = for {ip, _subnet} <- info.ip_subnets, do: {:rule, table_index, ip}

    # The local routes ensure that any packets sent to a LAN go out the
    # appropriate interface. These need to be ordered by metric so that if two
    # or more interfaces connect to the same LAN, they're prioritized.
    local_routes =
      if info.ip_subnets != [] do
        {ip, subnet_bits} = hd(info.ip_subnets)

        [
          {:local_route, ifname, ip, subnet_bits, 0, table_index},
          {:local_route, ifname, ip, subnet_bits, metric, :main}
        ]
      else
        []
      end

    # If a default gateway is set, add it to the source-routed table for the
    # interface and to the main routing table. In a multiple interface setup,
    # the main routing table will have more than one default gateway and the
    # metric will determine which one is used.
    tables =
      if info.default_gateway != nil and rules != [] do
        [
          {:default_route, ifname, info.default_gateway, 0, table_index},
          {:default_route, ifname, info.default_gateway, metric, :main}
        ]
      else
        []
      end

    rules ++ local_routes ++ tables
  end

  defp get_table_index(ifname, table_indices) do
    case Map.get(table_indices, ifname) do
      nil ->
        index = allocate_table_index(table_indices)
        new_table_indices = Map.put(table_indices, ifname, index)
        {new_table_indices, index}

      index ->
        {table_indices, index}
    end
  end

  defp allocate_table_index(table_indices) do
    # This shouldn't be called all that often and table_indices should
    # be small (number of real network interfaces), so performance "shouldn't"
    # matter...
    used = Map.values(table_indices)

    case Enum.find(rule_table_index_range(), fn n -> not Enum.member?(used, n) end) do
      nil ->
        raise "VintageNet.Route.Calculator ran out of table indices. This is probably due to more than `:max_interface_count` in use simultaneously."

      picked ->
        picked
    end
  end
end
