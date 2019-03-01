defmodule Nerves.NetworkNG.Interface do
  defmodule BroadCast do
    @moduledoc false

    @type b_type :: :ivp4 | :ipv6

    @opaque t :: %__MODULE__{}

    defstruct type: nil, ip_address: ""

    def new(broadcast_type, ip_address) do
      struct(__MODULE__, type: broadcast_type, ip_address: ip_address)
    end

    def from_string(ip_string) do
      ip_string
      |> parse_broadcast_addresses()
      |> Enum.map(fn {type, address} -> new(type, address) end)
    end

    defp parse_broadcast_addresses(iface_info_string) do
      regex = ~r/brd [^\s]+/

      Regex.scan(regex, iface_info_string)
      |> List.flatten()
      |> Enum.flat_map(&(String.split(&1, " ") |> Enum.drop(1)))
      |> Enum.map(&tag_ip/1)
    end

    defp tag_ip(ip_string) do
      # Naive if check, will want to do better long term
      if ipv6?(ip_string) do
        {:ipv6, ip_string}
      else
        {:ipv4, ip_string}
      end
    end

    defp ipv6?(ip_string), do: ip_string |> String.split(":") |> length() == 6
  end

  @opaque t :: %__MODULE__{}

  defstruct name: "",
            enabled?: false,
            running?: false,
            raw_info: "",
            ipv4: "",
            ipv6: "",
            broadcast?: false,
            broadcast_addresses: []

  @type iface_name :: String.t()

  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @spec from_string(iface_name, String.t()) :: t()
  def from_string(iface_name, iface_info_string) do
    flag_opts = parse_iface_flags(iface_info_string)
    ipv4 = parse_inet4_ip_address(iface_info_string)
    ipv6 = parse_inet6_ip_address(iface_info_string)
    broadcast_addresses = BroadCast.from_string(iface_info_string)

    opts = [
      name: iface_name,
      raw_info: iface_info_string,
      ipv4: ipv4,
      ipv6: ipv6,
      broadcast_addresses: broadcast_addresses
    ]

    flag_opts
    |> Keyword.merge(opts)
    |> new()
  end

  defp parse_iface_flags(iface_info_string) do
    Regex.scan(~r/(?<=\<).*(?=\>)/, iface_info_string)
    |> List.flatten()
    |> Enum.flat_map(&String.split(&1, ","))
    |> Enum.reduce([], fn
      "UP", opts -> Keyword.put(opts, :enabled?, true)
      "LOWER_UP", opts -> Keyword.put(opts, :running?, true)
      "BROADCAST", opts -> Keyword.put(opts, :broadcast?, true)
      _, opts -> opts
    end)
  end

  def parse_inet4_ip_address(iface_info_string) do
    Regex.scan(~r/inet \b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b/, iface_info_string)
    |> List.flatten()
    |> list_first_with_default("")
    |> String.split(" ")
    |> Enum.drop(1)
    |> List.first()
  end

  def parse_inet6_ip_address(iface_info_string) do
    # Probably should use better Regex, but during the "make it work" phase
    # this should be okay
    regex = ~r/inet6 [^\s]+/

    Regex.scan(regex, iface_info_string)
    |> List.flatten()
    |> list_first_with_default("")
    |> String.split(" ")
    |> Enum.drop(1)
    |> List.first()
  end

  defp list_first_with_default([], default), do: default
  defp list_first_with_default(list, _), do: List.first(list)
end
