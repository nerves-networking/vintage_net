defmodule VintageNet.Route.DefaultMetric do
  @moduledoc """
  Default module for prioritizing network interfaces

  The priority order is:

  1. Internet-connected interfaces are chosen before LAN-connected interfaces
  2. Wired Ethernet, then wifi, then mobile and then any other interfaces
  3. The interface's weight is used to resolve ties. By default, the weight is
     derived from the interfaces index. E.g., `eth0`'s weight is 0 (highest priority)
     and `eth1`'s weight is 1 (next highest)
  """

  alias VintageNet.Route
  alias VintageNet.Route.InterfaceInfo

  # Priority order list
  #
  # `{:ethernet, :internet}` - Wired ethernet that's Internet connected
  # `{:ethernet, :_}` - Wired ethernet with any status
  # `{:_, :internet}` - Any Internet-connected network interface
  @prioritization [
    {:ethernet, :internet},
    {:wifi, :internet},
    {:mobile, :internet},
    {:_, :internet},
    {:ethernet, :lan},
    {:wifi, :lan},
    {:mobile, :lan},
    {:_, :lan}
  ]

  @doc """
  Compute the routing metric for an interface with a status

  This uses the prioritization list to figure out what number should
  be used for the Linux routing table metric. It could also be `:disabled`
  to indicate that a route shouldn't be added to the Linux routing tables
  at all.
  """
  @spec compute_metric(VintageNet.ifname(), InterfaceInfo.t()) :: Route.metric() | :disabled
  def compute_metric(_ifname, %InterfaceInfo{status: :disconnected} = _info) do
    # Short cut disconnected interfaces
    :disabled
  end

  def compute_metric(_ifname, %InterfaceInfo{} = info) do
    case Enum.find_index(@prioritization, fn option ->
           matches_option?(option, info.interface_type, info.status)
         end) do
      nil ->
        :disabled

      value ->
        # Don't return 0, since that looks like the metric wasn't set. Also space out the numbers.
        # (Lower numbers are higher priority).
        #
        # NOTE: The floor/1 call indicates to Dialyzer that the return value is
        #       guaranteed to be an integer.
        floor((value + 1) * 10 + info.weight)
    end
  end

  defp matches_option?({type, status}, type, status), do: true
  defp matches_option?({:_, status}, _type, status), do: true
  defp matches_option?({type, :_}, type, _status), do: true
  defp matches_option?(_option, _type, _status), do: false
end
