# SPDX-FileCopyrightText: 2019 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetTest.CapturingUdhcpdHandler do
  @moduledoc false

  @behaviour VintageNet.OSEventDispatcher.UdhcpdHandler

  require Logger

  @doc """
  """
  @impl VintageNet.OSEventDispatcher.UdhcpdHandler
  def lease_update(ifname, lease_file) do
    record(ifname, :lease_update, lease_file)
  end

  @doc """
  Return captured calls
  """
  @spec get() :: []
  def get() do
    Agent.get(__MODULE__, fn x -> x end)
  end

  @doc """
  Clear out captured calls
  """
  @spec clear() :: :ok
  def clear() do
    maybe_start()
    Agent.update(__MODULE__, fn _messages -> [] end)
  end

  defp record(ifname, op, info) do
    maybe_start()
    Agent.update(__MODULE__, fn messages -> [{ifname, op, info} | messages] end)
  end

  defp maybe_start() do
    case Process.whereis(__MODULE__) do
      nil ->
        {:ok, _pid} = Agent.start(fn -> [] end, name: __MODULE__)
        :ok

      _ ->
        :ok
    end
  end
end
