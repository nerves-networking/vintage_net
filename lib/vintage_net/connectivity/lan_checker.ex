defmodule VintageNet.Connectivity.LANChecker do
  @moduledoc """
  This GenServer monitors a network interface for LAN connectivity

  Currently LAN connectivity simply looks to see if it's possible to
  send a packet on the interface. It might or might not get to the
  desired destination on the LAN, but it won't obviously fail.

  This is an alternative to the InternetConnectivityChecker that
  actively monitors reachability to a host.
  """

  use GenServer

  alias VintageNet.RouteManager
  require Logger

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
        RouteManager.set_connection_status(ifname, :lan, "ifup")

      _not_true ->
        # If the physical layer isn't up, don't start polling until
        # we're notified that it is available.
        RouteManager.set_connection_status(ifname, :disconnected, "ifdown")
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, false, _meta},
        %{ifname: ifname} = state
      ) do
    # Physical layer is down. We're definitely disconnected.
    RouteManager.set_connection_status(ifname, :disconnected, "ifdown")
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, true, _meta},
        %{ifname: ifname} = state
      ) do
    # Physical layer is up. Optimistically assume that the LAN is accessible.

    # NOTE: Consider triggering based on whether the interface has an IP address or not.
    RouteManager.set_connection_status(ifname, :lan, "ifup")

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], old_value, nil, _meta},
        %{ifname: ifname} = state
      ) do
    # The interface was completely removed!
    if old_value, do: RouteManager.set_connection_status(ifname, :disconnected, "removed!")
    {:noreply, state}
  end

  defp lower_up_property(ifname) do
    ["interface", ifname, "lower_up"]
  end
end
