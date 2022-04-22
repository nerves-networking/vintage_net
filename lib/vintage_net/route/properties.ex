defmodule VintageNet.Route.Properties do
  @moduledoc """
  This module contains helpers for updating the global routing properties.

  These include:
  * `["available_interfaces"]`
  * `["connection"]`
  """
  alias VintageNet.Route
  alias VintageNet.Route.Calculator

  @doc """
  Update the available_interfaces property based on the low level routes

  This function orders interfaces based on metric just like Linux does
  """
  @spec update_available_interfaces(Route.entries()) :: :ok
  def update_available_interfaces(routes) do
    # Available interfaces are those with local routes
    # in priority order.

    interfaces =
      routes
      |> local_routes()
      |> Enum.sort()
      |> Enum.map(fn {_metric, ifname} -> ifname end)

    PropertyTable.put(VintageNet, ["available_interfaces"], interfaces)
  end

  @doc """
  Update the overall connection status

  `:disconnected` < `:lan` < `:internet`
  """
  @spec update_best_connection(Calculator.interface_infos()) :: :ok
  def update_best_connection(infos) do
    best = best_connection(infos)
    PropertyTable.put(VintageNet, ["connection"], best)
  end

  defp best_connection(infos) when infos == %{} do
    :disconnected
  end

  defp best_connection(infos) do
    infos
    |> Enum.map(&get_status/1)
    |> Enum.max_by(&status_to_priority/1)
  end

  defp get_status({_ifname, %{status: status}}), do: status
  defp status_to_priority(:disconnected), do: 0
  defp status_to_priority(:lan), do: 1
  defp status_to_priority(:internet), do: 2

  defp local_routes(routes) do
    for {:local_route, ifname, _address, _subnet_bits, metric, :main} <- routes,
        do: {metric, ifname}
  end

  @doc """
  Update every interface's connection status
  """
  @spec update_connection_status(Calculator.interface_infos()) :: :ok
  def update_connection_status(infos) do
    props =
      for {ifname, %{status: status}} <- infos, do: {["interface", ifname, "connection"], status}

    PropertyTable.put_many(VintageNet, props)
  end
end
