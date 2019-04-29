defmodule VintageNet.Persistence do
  @moduledoc """
  Customize the way VintageNet saves and loads configurations
  """

  @doc """
  Save the configuration for the specified interface
  """
  @callback save(ifname :: String.t(), config :: map()) :: :ok | {:error, atom()}

  @doc """
  Load the configuration of an interface
  """
  @callback load(ifname :: String.t()) :: {:ok, map()} | {:error, reason :: any()}
end
