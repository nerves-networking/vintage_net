defmodule VintageNet.Route.InterfaceInfo do
  @moduledoc """
  Routing information for an interface
  """

  defstruct default_gateway: nil,
            weight: 0,
            ip_subnets: [],
            interface_type: :unknown,
            status: :disconnected

  @typedoc """
  A weight that can be used to differentiate two interfaces that would otherwise be the same priority

  Lower weights are higher priority.
  """
  @type weight :: 0..9

  @typedoc """
  Routing information

  * `:default_gateway` - default gateway IP address or `nil` if there isn't one
  * `:ip_subnets` - zero or more IP addresses and prefix lengths for what's on this LAN
  * `:weight` - a value to pass on when calculating the routing table metric for weighting
    an interface over another one
  * `:interface_type` - a rough categorization of the interface between `:ethernet`, `:wifi`,
    `:cellular`, etc. based on the name. See `VintageNet.Interface.NameUtilities`.
  * `:status` - whether the interface is `:disconnected`, `:lan`, or `:internet`
  """
  @type t :: %__MODULE__{
          default_gateway: :inet.ip_address() | nil,
          weight: weight(),
          ip_subnets: [{:inet.ip_address(), VintageNet.prefix_length()}],
          interface_type: VintageNet.interface_type(),
          status: VintageNet.connection_status()
        }
end
