defmodule VintageNet.Interface.LANConnectivityChecker do
  use GenServer
  require Logger

  alias VintageNet.{PropertyTable, RouteManager}

  @moduledoc """
  This GenServer monitors a network interface for LAN connectivity

  Currently LAN connectivity simply looks to see if it's possible to
  send a packet on the interface. It might or might not get to the
  desired destination on the LAN, but it won't obviously fail.

  This is an alternative to the InternetConnectivityChecker that
  actively monitors reachability to a host.
  """

  @doc """
  Start the connectivity checker GenServer
  """
  @spec start_link(VintageNet.ifname()) :: GenServer.on_start()
  def start_link(ifname) do
    GenServer.start_link(__MODULE__, ifname)
  end

  @impl GenServer
  def init(ifname) do
    state = %{ifname: ifname}
    {:ok, state, {:continue, :continue}}
  end

  @impl GenServer
  def handle_continue(:continue, %{ifname: ifname} = state) do
    VintageNet.subscribe(lower_up_property(ifname))

    case VintageNet.get(lower_up_property(ifname)) do
      true ->
        set_connectivity(ifname, :lan)

      _not_true ->
        # If the physical layer isn't up, don't start polling until
        # we're notified that it is available.
        set_connectivity(ifname, :disconnected)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, false, _meta},
        %{ifname: ifname} = state
      ) do
    # Physical layer is down. We're definitely disconnected.
    set_connectivity(ifname, :disconnected)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, true, _meta},
        %{ifname: ifname} = state
      ) do
    # Physical layer is up. Optimistically assume that the LAN is accessible.

    # NOTE: Consider triggering based on whether the interface has an IP address or not.
    set_connectivity(ifname, :lan)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], old_value, nil, _meta},
        %{ifname: ifname} = state
      ) do
    # The interface was completely removed!
    if old_value, do: set_connectivity(ifname, :disconnected)
    {:noreply, state}
  end

  defp set_connectivity(ifname, connectivity) do
    RouteManager.set_connection_status(ifname, connectivity)
    PropertyTable.put(VintageNet, ["interface", ifname, "connection"], connectivity)
  end

  defp lower_up_property(ifname) do
    ["interface", ifname, "lower_up"]
  end
end
