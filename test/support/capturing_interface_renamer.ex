# SPDX-FileCopyrightText: 2020 Connor Rigby
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetTest.CapturingInterfaceRenamer do
  @moduledoc false
  @behaviour VintageNet.InterfaceRenamer

  @impl VintageNet.InterfaceRenamer
  def rename_interface(from, to) do
    maybe_start()
    Agent.update(__MODULE__, fn messages -> [{:rename, from, to} | messages] end)
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
