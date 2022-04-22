defmodule VintageNet.InterfacesMonitor.Info do
  @moduledoc false

  alias VintageNet.IP

  @link_if_properties [:lower_up, :mac_address]
  @address_if_properties [:addresses]

  @all_if_properties [:present, :hw_path] ++ @link_if_properties ++ @address_if_properties

  defstruct ifname: nil,
            hw_path: "",
            link: %{},
            addresses: []

  @type t() :: %__MODULE__{
          ifname: VintageNet.ifname(),
          hw_path: String.t(),
          link: map(),
          addresses: [map()]
        }

  @doc """
  Create a new struct for caching interface notifications
  """
  @spec new(VintageNet.ifname(), String.t()) :: t()
  def new(ifname, hw_path \\ "") do
    %__MODULE__{ifname: ifname, hw_path: hw_path}
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

  or

  ```elixir
  %{
    address: {10, 64, 64, 64},
    family: :inet,
    label: "ppp0",
    local: {10, 0, 95, 181},
    permanent: true,
    prefixlen: 32,
    scope: :universe
  }
  ```

  or

  ```elixir
  %{address: {0, 0, 0, 0, 0, 0, 0, 1}, family: :inet6, permanent: true, prefixlen: 128, scope: :host}
  ```
  """
  @spec newaddr(t(), map()) :: t()
  def newaddr(info, address_report) do
    info = deladdr(info, address_report)

    new_addresses = [address_report | info.addresses]

    %{info | addresses: new_addresses}
  end

  @doc """
  Handle the deladdr report
  """
  @spec deladdr(t(), map()) :: t()
  def deladdr(info, address_report) do
    new_addresses =
      info.addresses
      |> Enum.filter(fn entry -> entry.address != address_report.address end)

    %{info | addresses: new_addresses}
  end

  @doc """
  Remove all IPv4 addresses
  """
  @spec delete_ipv4_addresses(t()) :: t()
  def delete_ipv4_addresses(info) do
    new_addresses =
      info.addresses
      |> Enum.filter(fn entry -> tuple_size(entry.address) != 4 end)

    %{info | addresses: new_addresses}
  end

  @doc """
  Clear out all properties exported by this module
  """
  @spec clear_properties(VintageNet.ifname()) :: :ok
  def clear_properties(ifname) do
    Enum.each(@all_if_properties, fn property ->
      PropertyTable.delete(VintageNet, ["interface", ifname, to_string(property)])
    end)
  end

  @doc """
  Report that the interface is present
  """
  @spec update_present(t()) :: t()
  def update_present(%__MODULE__{ifname: ifname} = info) do
    PropertyTable.put_many(VintageNet, [
      {["interface", ifname, "present"], true},
      {["interface", ifname, "hw_path"], info.hw_path}
    ])

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
    PropertyTable.delete(VintageNet, ["interface", ifname, to_string(property)])
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
    # VintageNet uses the word `address` to refer to the IP address assigned to
    # the interface. If you don't know Linux networking, I think that's an
    # obvious use of that word. For point-to-point network links, though, Linux
    # reports both the local and remote addresses. The remote one is stored in
    # `address` and the local one is in `local`. Therefore, the code below uses
    # `local` since that's always the local side of the interface.
    for report <- address_reports do
      %{
        family: report.family,
        scope: report.scope,
        address: report[:local] || report.address,
        prefix_length: report.prefixlen,
        netmask: IP.prefix_length_to_subnet_mask(report.family, report.prefixlen)
      }
    end
  end
end
