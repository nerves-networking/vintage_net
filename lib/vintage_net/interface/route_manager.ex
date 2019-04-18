defmodule VintageNet.Interface.RouteManager do
  use GenServer

  alias VintageNet.Interface.Classification

  @moduledoc """
  This module manages the default route.

  Devices with more than one network interface may have more than one
  way of reaching the Internet. In other words, each interface can
  have its own default route. Linux has many ways of handling this
  situation including failing between interfaces and load balancing.
  Failure detection is limited to what the Linux kernel can see, though,
  so an Ethernet cable being unplugged is fine, but a router going down
  needs to be detected elsewhere.

  This module works by registering default routes with the Linux kernel.
  Linux will only send packets bound for the Internet using one interface
  which will be selected based on type. For example, the default ordering
  is to use wired interfaces in preference to WiFi and WiFi in preference
  to cellular.

  It is possible to annotate interfaces with higher level information on
  them. This lets you prefer a WiFi route that's internet connected over
  a wired route that's not.
  """

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
  @spec set_route(String.t(), String.t()) :: :ok
  def set_route(ifname, route) do
    GenServer.call(__MODULE__, {:set_route, ifname, route})
  end

  @doc """
  Set the connection status on an interface.

  Changing the connection status can reprioritize routing. The
  specified interface doesn't need to have a default route.
  """
  @spec set_connection_status(String.t(), Classification.connection_status()) :: :ok
  def set_connection_status(ifname, status) do
    GenServer.call(__MODULE__, {:set_connection_status, ifname, status})
  end

  @doc """
  Clear out the default gateway for an interface.
  """
  @spec clear_route(String.t()) :: :ok
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

  @impl true
  def init(_args) do
    state = %{prioritization: Classification.default_prioritization(), ifmap: %{}}
    {:ok, state}
  end

  @impl true
  def handle_call({:set_route, ifname, route}, _from, state) do
    # ifentry = %{domain: domain, nameservers: nameservers}
    # state = %{state | ifmap: Map.put(state.ifmap, ifname, ifentry)}
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:set_connection_status, ifname, status}, _from, state) do
    # ifentry = %{domain: domain, nameservers: nameservers}
    # state = %{state | ifmap: Map.put(state.ifmap, ifname, ifentry)}
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:clear_route, ifname}, _from, state) do
    # state = %{state | ifmap: Map.delete(state.ifmap, ifname)}
    {:reply, :ok, state}
  end
end
