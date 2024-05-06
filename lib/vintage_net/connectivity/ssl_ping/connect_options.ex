defmodule VintageNet.Connectivity.SSLPing.ConnectOptions do
  @moduledoc """
  Implement this behaviour for the use with the SSLPing module. This allows users
  to configure how the `:ssl.connect/3` behaves. For example, if using Amazon AWS IOT,
  users will want to provide a `:cacerts` option with the list of certs. 
  """

  @doc """
  Callback to be called before `:ssl.connect/3`. Implementations should return
  the following options in most cases:

  * `:cacerts` - List of cacerts to be used in verification.
  * `verify: :verify_peer` - Upon connect, verify the other connection.
  """
  @callback connect_options() :: [:ssl.tls_client_option()]
end
