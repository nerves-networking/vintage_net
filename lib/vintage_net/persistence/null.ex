defmodule VintageNet.Persistence.Null do
  @behaviour VintageNet.Persistence

  @moduledoc """
  Don't save or load configuration at all.
  """

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
