defmodule VintageNet.Connectivity.Ping do
  @moduledoc """
  Behaviour definition for internet connectivity checking

  See `VintageNet.Connectivity.TCPPing` and `VintageNet.Connectivity.SSLPing`
  for built-in internet connectivity checkers.

  Custom implementations can be used by adding to the `:internet_host_list` option in
  the application environment for `:vintage_net`.
  """

  @typedoc """
  A method and options for checking internet connectivity
  """
  @type ping_spec() :: {module :: module(), opts :: keyword()}

  @doc """
  Accept/reject a ping spec and normalize any options

  This is called at initialization time. If this returns an error, then it
  will be removed from the list of internet checkers.
  """
  @callback normalize(spec :: ping_spec()) :: {:ok, ping_spec()} | :error

  @doc """
  Expand this checker to one that single endpoint checks

  It's possible for an internet connectivity checker to have multiple ways of
  confirming internet connectivity. This happens when pinging DNS endpoints.
  DNS could return zero or more destination IP addresses. If it returns zero
  then this checker is definitely going to fail. If it returns more thn one
  endpoint, then we want to check them one at a time rather than all at once.
  VintageNet will call the `ping/2` callback one at a time based on the results
  of this function.
  """
  @callback expand(spec :: ping_spec()) :: [{ping_spec()}]

  @doc """
  Perform a check on an interface. the second argument is a keyword argument
  list that can have any data supplied via config. It will always have the following:

  * `host` - either an IP address or DNS hostname that should be checked for connectivity.
  * `port` - network port to be used during the check.
  """
  @callback ping(ifname :: VintageNet.ifname(), spec :: ping_spec()) :: :ok | {:error, term()}
end
