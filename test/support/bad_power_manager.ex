# SPDX-FileCopyrightText: 2020 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetTest.BadPowerManager do
  @moduledoc false
  @behaviour VintageNet.PowerManager

  @impl VintageNet.PowerManager
  def init(_args) do
    {:ok, :no_state}
  end

  @impl VintageNet.PowerManager
  def power_on(_state) do
    raise RuntimeError, "oops"
  end

  @impl VintageNet.PowerManager
  def start_powering_off(state) do
    {:ok, state, 0}
  end

  @impl VintageNet.PowerManager
  def power_off(state) do
    {:ok, state, 0}
  end

  @impl VintageNet.PowerManager
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
