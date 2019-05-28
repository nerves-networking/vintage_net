defmodule VintageNet.Technology do
  alias VintageNet.Interface.RawConfig

  @moduledoc """
  Technologies define how network interface types work

  VintageNet comes with several built-in technologies, but more can be
  added or existing ones modified by implementing the `Technology` behaviour.
  """

  @doc """
  Normalize a configuration

  Technologies can use this to update provided configurations so that same configurations that could
  be specified in multiple ways have a single representation.
  """
  @callback normalize(config :: map()) :: {:ok, map()} | {:error, any()}

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

  @doc """
  Check that the system has all of the required programs for this technology

  This is intended to help identify missing programs without configuring
  a network.
  """
  @callback check_system(opts :: keyword()) :: :ok | {:error, String.t()}
end
