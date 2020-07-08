defmodule VintageNetTest.CapturingUdhcpcHandler do
  @moduledoc false

  @behaviour VintageNet.ToElixir.UdhcpcHandler

  require Logger

  @doc """
  """
  @impl VintageNet.ToElixir.UdhcpcHandler
  def deconfig(ifname, info) do
    record(ifname, :deconfig, info)
  end

  @doc """
  """
  @impl VintageNet.ToElixir.UdhcpcHandler
  def leasefail(ifname, info) do
    record(ifname, :leasefail, info)
  end

  @doc """
  """
  @impl VintageNet.ToElixir.UdhcpcHandler
  def nak(ifname, info) do
    record(ifname, :nak, info)
  end

  @doc """
  """
  @impl VintageNet.ToElixir.UdhcpcHandler
  def renew(ifname, info) do
    record(ifname, :renew, info)
  end

  @doc """
  """
  @impl VintageNet.ToElixir.UdhcpcHandler
  def bound(ifname, info) do
    record(ifname, :bound, info)
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
