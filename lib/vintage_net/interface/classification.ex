defmodule VintageNet.Interface.Classification do
  @moduledoc """
  Module for classifying and prioritizing network interfaces
  """

  @typedoc """
  Prioritization for using default gateways

  Examples

  * `{:ethernet, :internet}` - Wired ethernet that's Internet connected
  * `{:ethernet, :_}` - Wired ethernet with any status
  * `{:_, :internet}` - Any Internet-connected network interface
  """
  @type prioritization :: {VintageNet.interface_type() | :_, VintageNet.connection_status() | :_}

  @typedoc """
  A weight used to disambiguate interfaces that would otherwise have the same priority

  Low weights are higher priority.
  """
  @type weight :: 0..9

  @doc """
  Compute the routing metric for an interface with a status

  This uses the prioritization list to figure out what number should
  be used for the Linux routing table metric. It could also be `:disabled`
  to indicate that a route shouldn't be added to the Linux routing tables
  at all.
  """
  @spec compute_metric(VintageNet.interface_type(), VintageNet.connection_status(), weight(), [
          prioritization()
        ]) ::
          pos_integer() | :disabled
  def compute_metric(_type, :disconnected, _weight, _prioritization), do: :disabled

  def compute_metric(type, status, weight, prioritization) when status in [:lan, :internet] do
    case Enum.find_index(prioritization, fn option -> matches_option?(option, type, status) end) do
      nil ->
        :disabled

      value ->
        # Don't return 0, since that looks like the metric wasn't set. Also space out the numbers.
        # (Lower numbers are higher priority)
        (value + 1) * 10 + weight
    end
  end

  defp matches_option?({type, status}, type, status), do: true
  defp matches_option?({:_, status}, _type, status), do: true
  defp matches_option?({type, :_}, type, _status), do: true
  defp matches_option?(_option, _type, _status), do: false

  @doc """
  Return a reasonable default for prioritizing interfaces

  The logic is that Internet-connected interfaces are prioritized first
  and after than Ethernet is preferred over WiFi and WiFi over LTE.
  """
  @spec default_prioritization() :: [prioritization()]
  def default_prioritization() do
    [
      {:ethernet, :internet},
      {:wifi, :internet},
      {:mobile, :internet},
      {:_, :internet},
      {:ethernet, :lan},
      {:wifi, :lan},
      {:mobile, :lan},
      {:_, :lan}
    ]
  end
end
