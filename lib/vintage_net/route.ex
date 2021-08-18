defmodule VintageNet.Route do
  @moduledoc """
  Types for handling routing tables
  """

  alias VintageNet.Route.InterfaceInfo

  @typedoc """
  Metric (priority) for a routing table entry
  """
  @type metric :: 0..32767

  @typedoc """
  Linux routing table index

  `:main` is table 254, `:local` is table 255. `:default` is normally the same as `:main`.
  """
  @type table_index :: 0..255 | :main | :local | :default

  @typedoc """
  An IP route rule

  If the source address matches the 3rd element, then use the routing table specified by the
  2nd element.
  """
  @type rule :: {:rule, table_index(), :inet.ip_address()}

  @typedoc """
  A default route entry

  The IP address is the default gateway
  """
  @type default_route ::
          {:default_route, VintageNet.ifname(), :inet.ip_address(), metric(), table_index()}

  @typedoc """
  A local route entry

  This is for routing packets to the LAN
  """
  @type local_route ::
          {:local_route, VintageNet.ifname(), :inet.ip_address(), metric(), table_index()}

  @typedoc """
  A routing table entry

  This can be turned into real Linux IP routing table entry.
  """
  @type entry :: rule() | default_route() | local_route()

  @typedoc """
  A list of routing table entries
  """
  @type entries :: [entry()]

  @typedoc """
  Compute a route metric value from information about the interface

  See `VintageNet.Route.DefaultMetric.compute_metric/2` for an example. This can be
  set using the `:route_metric_fun` application environment key.
  """
  @type route_metric_fun() :: (VintageNet.ifname(), InterfaceInfo.t() -> metric())
end
