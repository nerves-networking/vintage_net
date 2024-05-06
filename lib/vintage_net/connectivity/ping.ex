defmodule VintageNet.Connectivity.Ping do
  @moduledoc """
  Behaviour definition for custom internet connectivity validation. The two
  official implementations for this include TCPPing and SSLPing. Users may
  specify additional modules via `config.exs` entry. 
  """

  @doc """
  Perform a check on an interface. the second argument is a keyword argument
  list that can have any data supplied via config. It will always have the following:

  * `host` - either an IP address or DNS hostname that should be checked for connectivity.
  * `port` - network port to be used during the check.  
  """
  @callback ping(ifname :: VintageNet.ifname(), opts :: Keyword.t()) :: :ok | {:error, term()}
end
