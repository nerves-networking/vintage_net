defmodule VintageNet.Persistence do
  @moduledoc """
  Customize the way VintageNet saves and loads configurations
  """

  @doc """
  Enumerate the interfaces that have saved configurations

  This returns a list of interface names.
  """
  @callback enumerate() :: [String.t()]

  @doc """
  Save the configuration for the specified interface
  """
  @callback save(ifname :: String.t(), config :: map()) :: :ok | {:error, atom()}

  @doc """
  Load the configuration of an interface
  """
  @callback load(ifname :: String.t()) :: {:ok, map()} | {:error, reason :: any()}

  @doc """
  Clear out a previously saved configuration
  """
  @callback clear(ifname :: String.t()) :: :ok

  @spec call(atom(), [any()]) :: any()
  def call(fun, args) do
    Application.get_env(:vintage_net, :persistence)
    |> apply(fun, args)
  end
end
