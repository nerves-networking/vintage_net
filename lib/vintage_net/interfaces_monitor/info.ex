defmodule VintageNet.InterfacesMonitor.Info do
  @moduledoc false

  alias VintageNet.PropertyTable

  @link_if_properties [:lower_up, :mac_address]
  @address_if_properties [:addresses]

  @all_if_properties [:present] ++ @link_if_properties ++ @address_if_properties

  defstruct ifname: nil,
            link: %{},
            addresses: []

  @type t() :: %__MODULE__{ifname: VintageNet.ifname(), link: map(), addresses: [map()]}

  @doc """
  Create a new struct for caching interface notifications
  """
  @spec new(VintageNet.ifname()) :: t()
  def new(ifname) do
    %__MODULE__{ifname: ifname}
  end

  @doc """
  Add/replace an address report to the interface info

  Link reports have the form:

  ```elixir
  %{
    broadcast: true,
    lower_up: true,
    mac_address: "70:85:c2:8f:98:e1",
    mac_broadcast: "ff:ff:ff:ff:ff:ff",
    mtu: 1500,
    multicast: true,
    operstate: :down,
    running: false,
    stats: %{
      collisions: 0,
      multicast: 0,
      rx_bytes: 0,
      rx_dropped: 0,
      rx_errors: 0,
      rx_packets: 0,
      tx_bytes: 0,
      tx_dropped: 0,
      tx_errors: 0,
      tx_packets: 0
    },
    type: :ethernet,
    up: true
  }
  ```
  """
  @spec newlink(t(), map()) :: t()
  def newlink(info, link_report) do
    %{info | link: link_report}
  end

  @doc """
  Add/replace an address report to the interface info

  Address reports have the form:

  ```elixir
  %{
    address: {192, 168, 10, 10},
    broadcast: {192, 168, 10, 255},
    family: :inet,
    label: "eth0",
    local: {192, 168, 10, 10},
    permanent: false,
    prefixlen: 24,
    scope: :universe
  }
  ```
  """
  @spec newaddr(t(), map()) :: t()
  def newaddr(info, address_report) do
    info = deladdr(info, address_report)

    new_addresses = [address_report | info.addresses]

    %{info | addresses: new_addresses}
  end

  @doc """
  Remove and address from the interface info
  """
  @spec deladdr(t(), map()) :: t()
  def deladdr(info, address_report) do
    new_addresses =
      info.addresses
      |> Enum.filter(fn entry -> entry.address != address_report.address end)

    %{info | addresses: new_addresses}
  end

  @doc """
  Clear out all properties exported by this module
  """
  @spec clear_properties(VintageNet.ifname()) :: :ok
  def clear_properties(ifname) do
    Enum.each(@all_if_properties, fn property ->
      PropertyTable.clear(VintageNet, ["interface", ifname, to_string(property)])
    end)
  end

  @doc """
  Report that the interface is present
  """
  @spec update_present(t()) :: t()
  def update_present(%__MODULE__{ifname: ifname} = info) do
    PropertyTable.put(VintageNet, ["interface", ifname, "present"], true)
    info
  end

  @doc """
  Update link-specific properties
  """
  @spec update_link_properties(t()) :: t()
  def update_link_properties(%__MODULE__{ifname: ifname, link: link_report} = info) do
    Enum.each(@link_if_properties, fn property ->
      update_link_property(ifname, property, Map.get(link_report, property))
    end)

    info
  end

  defp update_link_property(ifname, property, nil) do
    PropertyTable.clear(VintageNet, ["interface", ifname, to_string(property)])
  end

  defp update_link_property(ifname, property, value) do
    PropertyTable.put(VintageNet, ["interface", ifname, to_string(property)], value)
  end

  @doc """
  Update address-specific properties
  """
  @spec update_address_properties(t()) :: t()
  def update_address_properties(%__MODULE__{ifname: ifname, addresses: address_reports} = info) do
    addresses = address_reports_to_property(address_reports)
    PropertyTable.put(VintageNet, ["interface", ifname, "addresses"], addresses)
    info
  end

  defp address_reports_to_property(address_reports) do
    for report <- address_reports do
      %{
        family: report.family,
        scope: report.scope,
        address: report.address,
        netmask: compute_netmask(report.family, report.prefixlen)
      }
    end
  end

  defp compute_netmask(:inet, len) do
    rest = 32 - len
    <<a, b, c, d>> = <<-1::size(len), 0::size(rest)>>
    {a, b, c, d}
  end

  defp compute_netmask(:inet6, len) do
    rest = 128 - len

    <<a::size(16), b::size(16), c::size(16), d::size(16), e::size(16), f::size(16), g::size(16),
      h::size(16)>> = <<-1::size(len), 0::size(rest)>>

    {a, b, c, d, e, f, g, h}
  end
end
