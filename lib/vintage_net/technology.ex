defmodule VintageNet.Technology do
  alias VintageNet.Interface.RawConfig

  @moduledoc """
  Technologies define how network interface types work

  VintageNet comes with several built-in technologies, but more can be
  added or existing ones modified by implementing the `Technology` behaviour.
  """

  @doc """
  Convert a technology-specific configuration to one for VintageNet
  """
  @callback to_raw_config(VintageNet.ifname(), config :: map(), opts :: keyword()) ::
              {:ok, RawConfig.t()} | {:error, any()}

  @doc """
  Handle an ioctl that has been requested on the network interface

  The function runs isolated in its own process and only one ioctl is guaranteed
  to be running at a time. `VintageNet` will handle crashes and hangs and unceremoniously
  kill the ioctl if the user changes their mind and reconfigures the network interface.

  Ioctl support is optional. Examples of `ioctl`s include:

  * `:scan` - scan for WiFi networks
  * `:statistics` - return a map of network statistics
  """
  @callback ioctl(VintageNet.ifname(), command :: atom(), args :: list()) ::
              :ok | {:ok, any()} | {:error, any()}

  @spec to_raw_config!(atom(), map()) :: RawConfig.t()
  def to_raw_config!(implementation, config) do
    case implementation.to_raw_config(config) do
      {:ok, data} -> data
      {:error, error} -> raise ArgumentError, "Error in configuration: #{error}"
    end
  end
end
