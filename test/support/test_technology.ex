defmodule VintageNetTest.TestTechnology do
  @behaviour VintageNet.Technology

  alias VintageNet.Interface.RawConfig

  @moduledoc """
  Support for unit testing APIs that require a Technology behaviour
  """

  @impl true
  def normalize(config), do: {:ok, config}

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
  def ioctl(_ifname, :echo, [what]) do
    # Echo back our argument
    {:ok, what}
  end

  def ioctl(_ifname, :oops, _args) do
    raise "Intentional ioctl oops"
  end

  def ioctl(_ifname, :sleep, [millis]) do
    Process.sleep(millis)
  end

  def ioctl(_ifname, _command, _args) do
    {:error, :unsupported}
  end

  @impl true
  def check_system(_opts) do
    :ok
  end
end
