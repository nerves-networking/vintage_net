defmodule VintageNet.Technology.Null do
  @behaviour VintageNet.Technology

  alias VintageNet.Interface.RawConfig

  @moduledoc """
  An interface with this technology is unconfigured
  """
  @impl true
  def to_raw_config(ifname, _config \\ %{}, _opts \\ []) do
    {:ok,
     %RawConfig{
       ifname: ifname,
       type: __MODULE__,
       source_config: %{type: __MODULE__},
       require_interface: false
     }}
  end

  @impl true
  def ioctl(_ifname, _command, _args) do
    {:error, :unsupported}
  end

  @impl true
  def check_system(_opts), do: :ok
end
