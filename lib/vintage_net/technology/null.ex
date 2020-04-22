defmodule VintageNet.Technology.Null do
  @behaviour VintageNet.Technology

  alias VintageNet.Interface.RawConfig

  @null_config %{type: __MODULE__}

  @moduledoc """
  An interface with this technology is unconfigured
  """

  @impl true
  def normalize(_config), do: @null_config

  @impl true
  def to_raw_config(ifname, _config \\ %{}, _opts \\ []) do
    %RawConfig{
      ifname: ifname,
      type: __MODULE__,
      source_config: @null_config,
      required_ifnames: []
    }
  end

  @impl true
  def ioctl(_ifname, _command, _args) do
    {:error, :unsupported}
  end

  @impl true
  def check_system(_opts), do: :ok
end
