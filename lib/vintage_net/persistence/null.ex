defmodule VintageNet.Persistence.Null do
  @moduledoc """
  Don't save or load configuration at all.
  """
  @behaviour VintageNet.Persistence

  @impl VintageNet.Persistence
  def save(_ifname, _config) do
    :ok
  end

  @impl VintageNet.Persistence
  def load(_ifname) do
    {:error, :enotsupported}
  end

  @impl VintageNet.Persistence
  def clear(_ifname) do
    :ok
  end

  @impl VintageNet.Persistence
  def enumerate() do
    []
  end
end
