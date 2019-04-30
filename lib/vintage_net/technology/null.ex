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
       source_config: %{type: __MODULE__}
     }}
  end

  @impl true
  def handle_ioctl(_ifname, _ioctl) do
    {:error, :unconfigured}
  end
end
