defmodule VintageNet.Technology.Null do
  @moduledoc """
  An interface with this technology is unconfigured
  """
  @behaviour VintageNet.Technology

  alias VintageNet.Interface.RawConfig

  @null_config %{type: __MODULE__}

  @impl VintageNet.Technology
  def normalize(_config), do: @null_config

  @impl VintageNet.Technology
  def to_raw_config(ifname, _config \\ %{}, _opts \\ []) do
    %RawConfig{
      ifname: ifname,
      type: __MODULE__,
      source_config: @null_config,
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
