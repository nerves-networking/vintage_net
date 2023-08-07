defmodule VintageNet.Technology.Null do
  @moduledoc """
  An interface with this technology is unconfigured

  If this was due to an error, the reason field will have more information.
  """
  @behaviour VintageNet.Technology

  alias VintageNet.Interface.RawConfig

  @impl VintageNet.Technology
  def normalize(config) do
    reason = Map.get(config, :reason, "")
    %{type: __MODULE__, reason: reason}
  end

  @impl VintageNet.Technology
  def to_raw_config(ifname, config \\ %{}, _opts \\ []) do
    %RawConfig{
      ifname: ifname,
      type: __MODULE__,
      source_config: normalize(config),
      required_ifnames: []
    }
  end

  @impl VintageNet.Technology
  def ioctl(_ifname, _command, _args) do
    {:error, :unsupported}
  end

  @impl VintageNet.Technology
  def check_system(_opts), do: :ok
end
