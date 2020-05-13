defmodule VintageNet.ActivityMonitor.Server do
  use GenServer

  alias VintageNet.ActivityMonitor.Classifier

  @all_addresses ["interface", :_, "addresses"]

  @spec start_link(any) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Return what kind of activity was seen on an interface

  This only covers the latest measurement period. If bytes were
  both sent and received to another computer on the LAN or Internet,
  `:lan` or `:internet` will be returned. Otherwise, `:unknown` is
  returned since there could still have been activity from a
  transient or non-TCP connection.
  """
  @spec latest_activity(VintageNet.ifname()) :: Classifier.classification()
  def latest_activity(ifname) do
    GenServer.call(__MODULE__, {:latest_activity, ifname})
  end

  @impl true
  def init(_args) do
    VintageNet.subscribe(@all_addresses)

    addresses =
      VintageNet.match(@all_addresses)
      |> Enum.map(fn {["interface", ifname, "addresses"], if_addresses} ->
        {ifname, if_addresses}
      end)

    state = %{addresses: addresses}
    {:ok, state}
  end

  @impl true
  def handle_call({:latest_activity, ifname}, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({VintageNet, ["interface", ifname, "addresses"], _old, new, _}, state) do
    info = {ifname, new}
    new_addresses = List.keyreplace(state.addresses, ifname, 0, info)
    {:noreply, %{state | addresses: new_addresses}}
  end
end
