# SPDX-FileCopyrightText: 2020 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetTest.TestPowerManager do
  @moduledoc false
  @behaviour VintageNet.PowerManager

  defstruct hold_on_time: 50,
            time_to_power_off: 100,
            min_power_off_time: 10,
            power_on: 0,
            start_powering_off: 0,
            power_off: 0,
            last_handle_info: nil

  @doc """
  Return call counts for functions
  """
  @spec call_count(VintageNet.ifname(), :power_on | :start_powering_off | :power_off) ::
          non_neg_integer()
  def call_count(ifname, metric) when metric in [:power_on, :start_powering_off, :power_off] do
    {:ok, state} = get_state(ifname)
    Map.get(state.impl_state, metric)
  end

  @doc """
  Return the last message received by handle_info/2
  """
  @spec last_handle_info(VintageNet.ifname()) :: any()
  def last_handle_info(ifname) do
    {:ok, state} = get_state(ifname)
    state.impl_state.last_handle_info
  end

  @doc """
  Return the internal state for a power management controller
  """
  @spec get_state(VintageNet.ifname()) :: {:ok, map()} | {:error, String.t()}
  def get_state(ifname) do
    case Registry.lookup(VintageNet.PowerManager.Registry, ifname) do
      [{pid, nil}] ->
        state = :sys.get_state(pid)
        state.impl == VintageNetTest.TestPowerManager || raise "Unexpected internal state"
        {:ok, state}

      [] ->
        {:error, "#{ifname} isn't running power management"}
    end
  end

  @impl VintageNet.PowerManager
  def init(args) do
    {:ok, struct(__MODULE__, args)}
  end

  @impl VintageNet.PowerManager
  def power_on(state) do
    {:ok, %{state | power_on: state.power_on + 1}, state.hold_on_time}
  end

  @impl VintageNet.PowerManager
  def start_powering_off(state) do
    {:ok, %{state | start_powering_off: state.start_powering_off + 1}, state.time_to_power_off}
  end

  @impl VintageNet.PowerManager
  def power_off(state) do
    {:ok, %{state | power_off: state.power_off + 1}, state.min_power_off_time}
  end

  @impl VintageNet.PowerManager
  def handle_info(msg, state) do
    {:noreply, %{state | last_handle_info: msg}}
  end
end
