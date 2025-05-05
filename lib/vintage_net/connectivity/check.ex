defmodule VintageNet.Connectivity.Check do
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
  @type check_spec() :: {module :: module(), opts :: keyword()}

  @typedoc """
  Successful result of a connectivity check. Indicates what level
  of connectivity is available on an interface. 

  * First tuple element is a connection status:
      * `:lan`
      * `:internet`
  * Second element is a list of [PropertyTable](https://hexdocs.pm/property_table/) entries

  For example if using `wlan0`, returning a check_result of:
      
      {:internet, [{["connection", "public_ip"], {75, 140, 99, 231}}]}

  Will result in two properties in the property table:

  * `{["interface", "wlan0", "connection"], :internet}`
  * `{["interface", "wlan0", "connection", "public_ip"], {75, 140, 99, 231}}`

  """
  @type check_result() :: {VintageNet.connection_status(), [{[String.t()], any()}]}

  @doc """
  Accept/reject a ping spec and normalize any options

  This is called at initialization time. If this returns an error, then it
  will be removed from the list of internet checkers.
  """
  @callback normalize(spec :: check_spec()) :: {:ok, check_spec()} | :error

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
  @callback expand(spec :: check_spec()) :: [check_spec()]

  @doc """
  Perform a check on an interface. the second argument is a keyword argument
  list that can have any data supplied via config. 
  """
  @callback check(ifname :: VintageNet.ifname(), spec :: check_spec()) ::
              {:ok, check_result()} | {:error, term()}
end
