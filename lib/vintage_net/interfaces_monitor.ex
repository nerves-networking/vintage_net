defmodule VintageNet.InterfacesMonitor do
  @moduledoc """
  Monitor available interfaces

  Currently this works by polling the system for what interfaces are visible.
  They may or may not be configured.
  """

  use GenServer

  alias VintageNet.InterfacesMonitor.{HWPath, Info}

  require Logger

  defstruct port: nil,
            interface_info: %{}

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Force clear all addresses

  This is useful to notify everyone that an address should not be used
  immediately. This can be used to fix a race condition where the blip
  for an address going away to coming back isn't reported.
  """
  @spec force_clear_ipv4_addresses(VintageNet.ifname()) :: :ok
  def force_clear_ipv4_addresses(ifname) do
    GenServer.call(__MODULE__, {:force_clear_ipv4_addresses, ifname})
  end

  @impl GenServer
  def init(_args) do
    executable = :code.priv_dir(:vintage_net) ++ ~c"/if_monitor"

    case File.exists?(executable) do
      true ->
        port =
          Port.open({:spawn_executable, executable}, [
            {:packet, 2},
            :use_stdio,
            :binary,
            :exit_status
          ])

        {:ok, %__MODULE__{port: port}}

      false ->
        # This is only done for testing on OSX
        {:ok, %__MODULE__{}}
    end
  end

  @impl GenServer
  def handle_call({:force_clear_ipv4_addresses, ifname}, _from, state) do
    with {ifindex, old_info} <- get_by_ifname(state, ifname),
         new_info = Info.delete_ipv4_addresses(old_info),
         true <- old_info != new_info do
      new_info = Info.update_address_properties(new_info)

      new_state = %{state | interface_info: Map.put(state.interface_info, ifindex, new_info)}
      {:reply, :ok, new_state}
    else
      _ -> {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_info({port, {:data, raw_report}}, %{port: port} = state) do
    report = :erlang.binary_to_term(raw_report)

    #  Logger.debug("if_monitor: #{inspect(report, limit: :infinity)}")

    new_state = handle_report(state, report)

    {:noreply, new_state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.error("interfaces_monitor exited with status #{status}")
    {:stop, {:port_exited, status}, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
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

  defp get_by_ifname(state, ifname) do
    Enum.find_value(state.interface_info, fn {ifindex, info} ->
      case info do
        %{ifname: ^ifname} -> {ifindex, info}
        _ -> nil
      end
    end)
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
        hw_path = HWPath.query(ifname)

        Info.new(ifname, hw_path)
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
