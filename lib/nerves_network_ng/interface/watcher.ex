defmodule Nerves.NetworkNG.Interface.Watcher do
  alias Nerves.NetworkNG
  alias Nerves.NetworkNG.Interface

  use GenServer

  defmodule State do
    alias Nerves.NetworkNG.Interface.LoggerHandle
    defstruct interface: nil, handle_module: LoggerHandle
  end

  @spec start_link(Interface.iface_name()) :: GenServer.on_start()
  def start_link(interface_name) do
    GenServer.start_link(__MODULE__, interface_name)
  end

  def init(interface_name) do
    case NetworkNG.get_interface(interface_name) do
      {:ok, interface} ->
        check_timer()
        {:ok, %State{interface: interface}}

      {:error, _} = error ->
        {:stop, error}
    end
  end

  def handle_info(:check_interface, %State{interface: interface, handle_module: hmodule} = state) do
    iface_name = Interface.name(interface)
    {:ok, new_interface} = NetworkNG.get_interface(iface_name)

    case Interface.status_change(interface, new_interface) do
      :up -> apply(hmodule, :handle_up, [interface])
      :down -> apply(hmodule, :handle_down, [interface])
      :noop -> apply(hmodule, :handle_info, [interface])
    end

    check_timer()

    {:noreply, %{state | interface: new_interface}}
  end

  defp check_timer() do
    Process.send_after(self(), :check_interface, 5_000)
  end
end
