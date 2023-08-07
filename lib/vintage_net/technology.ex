defmodule VintageNet.Technology do
  @moduledoc """
  Technologies define how network interface types work

  VintageNet comes with several built-in technologies, but more can be
  added or existing ones modified by implementing the `Technology` behaviour.
  """

  alias VintageNet.Interface.RawConfig

  @doc """
  Normalize a configuration

  Technologies use this to update input configurations to a canonical
  representation. This includes things like inserting default fields,
  converting IP addresses passed in as strings to tuples, and deriving
  parameters so that they need not be derived again in the future.

  Configuration errors raise exceptions.
  """
  @callback normalize(config :: map()) :: map()

  @doc """
  Convert a technology-specific configuration to one for VintageNet

  The `config` is the normalized configuration map (`normalize/1` will have
  been called at some point so the technology does not need to call it again).

  The `opts` parameter contains VintageNet's application environment. This
  contains potentially useful file paths and other information.

  Configuration errors raise exceptions. Errors should be infrequent, though,
  since VintageNet will call `normalize/1` first and expects most errors to be
  caught by it.
  """
  @callback to_raw_config(VintageNet.ifname(), config :: map(), opts :: keyword()) ::
              RawConfig.t()

  @doc """
  Handle an ioctl that has been requested on the network interface

  The function runs isolated in its own process and only one ioctl is
  guaranteed to be running at a time. `VintageNet` will handle crashes and
  hangs and unceremoniously kill the ioctl if the user changes their mind and
  reconfigures the network interface.

  Ioctl support is optional. Examples of `ioctl`s include:

  * `:scan` - scan for WiFi networks
  * `:statistics` - return a map of network statistics
  """
  @callback ioctl(VintageNet.ifname(), command :: atom(), args :: list()) ::
              :ok | {:ok, any()} | {:error, any()}

  @doc """
  Check that the system has all of the required programs for this technology

  This is intended to help identify missing programs without configuring a
  network.
  """
  @callback check_system(opts :: keyword()) :: :ok | {:error, String.t()}

  @doc """
  Helper to fetch the Technology implementation from a configuration
  """
  @spec module_from_config!(%{:type => module, optional(any) => any}) :: module
  def module_from_config!(%{type: type}) when is_atom(type) do
    if Code.ensure_loaded?(type) do
      type
    else
      raise(ArgumentError, """
      Invalid technology #{inspect(type)}.

      Check the spelling and that you have the dependency that provides it in your mix.exs.
      See the `vintage_net` docs for examples.
      """)
    end
  end

  def module_from_config!(_missing) do
    raise(
      ArgumentError,
      """
      Missing :type field.

      This should be set to a network technology. These are provided in other libraries.
      See the `vintage_net` docs and cookbook for examples.
      """
    )
  end
end
