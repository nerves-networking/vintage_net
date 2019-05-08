defmodule VintageNet.Interface.Classification do
  @moduledoc """
  Module for classifying and prioritizing network interfaces
  """

  @typedoc """
  Categorize interfaces based on their technology
  """
  @type interface_type :: :ethernet | :wifi | :mobile | :local | :unknown

  @typedoc """
  Interface connection status

  * `:lan` - The interface is connected to the LAN, but may not be able
    reach the Internet
  * `:internet` - Packets going through the interface should be able to
    reach the Internet
  * `:disabled` - Don't use this interface
  """
  @type connection_status :: :lan | :internet | :disabled

  @typedoc """
  Prioritization for using default gateways

  Examples

  * `{:ethernet, :internet}` - Wired ethernet that's Internet connected
  * `{:ethernet, :_}` - Wired ethernet with any status
  * `{:_, :internet}` - Any Internet-connected network interface
  """
  @type prioritization :: {interface_type() | :_, connection_status() | :_}

  @doc """
  Classify a network type based on its name

  Examples

      iex> Classification.to_type("eth0")
      :ethernet

      iex> Classification.to_type("wlp5s0")
      :wifi

      iex> Classification.to_type("ppp0")
      :mobile

  """
  @spec to_type(VintageNet.ifname()) :: interface_type()
  def to_type("eth" <> _rest), do: :ethernet
  def to_type("en" <> _rest), do: :ethernet
  def to_type("wlan" <> _rest), do: :wifi
  def to_type("wl" <> _rest), do: :wifi
  def to_type("ra" <> _rest), do: :wifi
  def to_type("ppp" <> _rest), do: :mobile
  def to_type("lo" <> _rest), do: :local
  def to_type("tap" <> _rest), do: :local
  def to_type(_other), do: :unknown

  @doc """
  Compute the routing metric for an interface with a status

  This uses the prioritization list to figure out what number should
  be used for the Linux routing table metric. It could also be `:disabled`
  to indicate that a route shouldn't be added to the Linux routing tables
  at all.
  """
  @spec compute_metric(interface_type(), connection_status(), [prioritization()]) ::
          pos_integer() | :disabled
  def compute_metric(_type, :disabled, _prioritization), do: :disabled

  def compute_metric(type, status, prioritization) when is_atom(type) do
    case Enum.find_index(prioritization, fn option -> matches_option?(option, type, status) end) do
      nil ->
        :disabled

      value ->
        # Don't return 0, since that looks like the metric wasn't set. Also space out the numbers.
        # (Lower numbers are higher priority)
        (value + 1) * 10
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
