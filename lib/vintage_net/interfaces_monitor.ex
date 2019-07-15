defmodule VintageNet.InterfacesMonitor do
  @moduledoc """
  Monitor available interfaces

  Currently this works by polling the system for what interfaces are visible.
  They may or may not be configured.
  """

  use GenServer

  alias VintageNet.InterfacesMonitor.Info

  defmodule State do
    @moduledoc false

    defstruct port: nil,
              interface_info: %{}
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
    # IO.puts("Got: #{inspect(raw_report, limit: :infinity)}")
    report = :erlang.binary_to_term(raw_report)

    new_state = handle_report(state, report)

    {:noreply, new_state}
  end

  defp handle_report(state, {:newlink, ifname, ifindex, link_report}) do
    new_info =
      get_or_create_info(state, ifindex, ifname)
      |> Info.newlink(link_report)
      |> Info.update_link_properties()

    %{state | interface_info: Map.put(state.interface_info, ifindex, new_info)}
  end

  defp handle_report(state, {:dellink, ifname, ifindex, _link_report}) do
    Info.clear_properties(ifname)

    %{state | interface_info: Map.delete(state.interface_info, ifindex)}
  end

  defp handle_report(state, {:newaddr, ifindex, address_report}) do
    new_info =
      get_or_create_info(state, ifindex)
      |> Info.newaddr(address_report)
      |> Info.update_address_properties()

    %{state | interface_info: Map.put(state.interface_info, ifindex, new_info)}
  end

  defp handle_report(state, {:deladdr, ifindex, address_report}) do
    new_info =
      get_or_create_info(state, ifindex)
      |> Info.deladdr(address_report)
      |> Info.update_address_properties()

    %{state | interface_info: Map.put(state.interface_info, ifindex, new_info)}
  end

  defp get_or_create_info(state, ifindex, ifname) do
    case Map.fetch(state.interface_info, ifindex) do
      {:ok, %{ifname: ^ifname} = info} ->
        info

      {:ok, %{ifname: old_ifname} = info} ->
        Info.clear_properties(old_ifname)

        %{info | ifname: ifname}
        |> Info.update_present()
        |> Info.update_address_properties()

      _missing ->
        Info.new(ifname)
        |> Info.update_present()
    end
  end

  defp get_or_create_info(state, ifindex) do
    case Map.fetch(state.interface_info, ifindex) do
      {:ok, info} ->
        info

      _missing ->
        # Race between address and link notifications?
        Info.new("__unknown")
    end
  end
end
