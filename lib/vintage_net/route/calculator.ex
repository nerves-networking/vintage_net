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

  alias VintageNet.Route.InterfaceInfo
  alias VintageNet.Interface.Classification

  @type table_index :: 0..255 | :main | :local | :default
  @type metric :: 0..32767
  @type rule :: {:rule, table_index(), :inet.ip_address()}
  @type default_route ::
          {:default_route, VintageNet.ifname(), :inet.ip_address(), metric(), table_index()}
  @type local_route ::
          {:local_route, VintageNet.ifname(), :inet.ip_address(), metric(), table_index()}
  @type entry :: rule() | default_route() | local_route()
  @type entries :: [entry()]
  @type table_indices :: %{VintageNet.ifname() => table_index()}

  @type interface_infos :: %{VintageNet.ifname() => InterfaceInfo.t()}

  @doc """
  Initialize state carried between calculations
  """
  @spec init() :: table_indices()
  def init() do
    %{}
  end

  @doc """
  Compute a Linux routing table configuration

  The entries are ordered so that List.myers_difference/2 can be used to
  minimize the routing table changes.
  """
  @spec compute(table_indices(), interface_infos(), [Classification.prioritization()]) ::
          {table_indices(), entries()}
  def compute(table_indices, infos, prioritization) do
    {new_table_indices, entries} =
      Enum.reduce(infos, {table_indices, []}, &make_entries(&1, &2, prioritization))

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

  defp make_entries({ifname, info}, {table_indices, entries}, prioritization) do
    {new_table_indices, table_index} = get_table_index(ifname, table_indices)
    metric = InterfaceInfo.metric(info, prioritization)

    new_entries = routing_table_entries(metric, ifname, table_index, info)

    {new_table_indices, new_entries ++ entries}
  end

  defp routing_table_entries(:disabled, _ifname, _table_index, _info) do
    []
  end

  defp routing_table_entries(metric, ifname, table_index, info) do
    # Every package with a source IP address of this interface needs to using
    # routing table "table_index"
    rules = for {ip, _subnet} <- info.ip_subnets, do: {:rule, table_index, ip}

    # Local routes are needed so that any packets sent to the LAN goes out
    # the appropriate interface. These need to be ordered by metric so that
    # if two or more interfaces connect to the same LAN, they're prioritized.
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

    case Enum.find(100..200, fn n -> not Enum.member?(used, n) end) do
      nil ->
        raise "VintageNet.Route.Calculator ran out of table indices???"

      picked ->
        picked
    end
  end
end
