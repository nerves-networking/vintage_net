defmodule VintageNet.InterfacesMonitor do
  @moduledoc """
  Monitor available interfaces

  Currently this works by polling the system for what interfaces are visible. They may or may not be configured.
  """

  use GenServer

  alias VintageNet.PropertyTable

  defmodule State do
    @moduledoc false

    defstruct port: nil,
              known_interfaces: %{}
  end

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    executable = :code.priv_dir(:vintage_net) ++ '/if_monitor'

    case File.exists?(executable) do
      true ->
        port = Port.open({:spawn_executable, executable}, [{:packet, 2}, :use_stdio, :binary])

        {:ok, %State{port: port}}

      false ->
        # This is only done for testing on OSX
        {:ok, %State{}}
    end
  end

  @impl true
  def handle_info({_port, {:data, raw_report}}, state) do
    report = :erlang.binary_to_term(raw_report)

    new_state = handle_report(state, report)

    {:noreply, new_state}
  end

  defp handle_report(state, {:added, ifname, ifindex}) do
    new_known_interfaces = Map.put(state.known_interfaces, ifindex, ifname)
    update_present(ifname, true)

    %{state | known_interfaces: new_known_interfaces}
  end

  defp handle_report(state, {:renamed, ifname, ifindex}) do
    case Map.fetch(state.known_interfaces, ifindex) do
      {:ok, old_ifname} ->
        state
        |> handle_report({:removed, old_ifname, ifindex})
        |> handle_report({:added, ifname, ifindex})

      _error ->
        handle_report(state, {:added, ifname, ifindex})
    end
  end

  defp handle_report(state, {:removed, ifname, ifindex}) do
    new_known_interfaces = Map.delete(state.known_interfaces, ifindex)
    clear_properties(ifname)

    %{state | known_interfaces: new_known_interfaces}
  end

  defp handle_report(state, {:report, ifname, ifindex, info}) do
    new_state =
      case Map.fetch(state.known_interfaces, ifindex) do
        {:ok, ^ifname} ->
          state

        {:ok, other_ifname} ->
          raise "Unexpected ifname: #{other_ifname}. Wanted #{ifname}"

        _error ->
          handle_report(state, {:added, ifname, ifindex})
      end

    update_lower_up(ifname, info)
    update_mac_address(ifname, info)

    new_state
  end

  defp clear_properties(ifname) do
    PropertyTable.clear(VintageNet, ["interface", ifname, "present"])
    PropertyTable.clear(VintageNet, ["interface", ifname, "lower_up"])
    PropertyTable.clear(VintageNet, ["interface", ifname, "mac_address"])
  end

  defp update_present(ifname, value) do
    PropertyTable.put(VintageNet, ["interface", ifname, "present"], value)
  end

  defp update_lower_up(ifname, %{lower_up: value}) do
    PropertyTable.put(VintageNet, ["interface", ifname, "lower_up"], value)
  end

  defp update_mac_address(ifname, %{mac_address: value}) do
    PropertyTable.put(VintageNet, ["interface", ifname, "mac_address"], value)
  end
end
