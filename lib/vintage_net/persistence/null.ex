defmodule VintageNet.Persistence.Null do
  @behaviour VintageNet.Persistence

  @moduledoc """
  Don't save or load configuration at all. 
  """

  @impl true
  def save(_ifname, _config) do
    :ok
  end

  @impl true
  def load(_ifname) do
    {:error, :enotsupported}
  end

  @impl true
  def clear(_ifname) do
    :ok
  end

  @impl true
  def enumerate() do
    []
  end
end
