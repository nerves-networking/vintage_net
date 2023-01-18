defmodule VintageNet.DHCP.Options do
  @moduledoc """
  DHCP Options
  """

  alias VintageNet.IP
  require Logger

  @typedoc """
  A map of options and other information reported by udhcpc

  Here's an example:

  ```elixir
  %{
    broadcast: {192, 168, 7, 255},
    dns: {192, 168, 7, 1},
    domain: "hunleth.lan",
    hostname: "nerves-9780",
    ip: {192, 168, 7, 190},
    lease: 86400,
    mask: 24,
    router: {192, 168, 7, 1},
    serverid: {192, 168, 7, 1},
    siaddr: {192, 168, 7, 1},
    subnet: {255, 255, 255, 0}
  }
  ```
  """
  @type t() :: %{
          optional(:ip) => :inet.ip_address(),
          optional(:mask) => non_neg_integer(),
          optional(:siaddr) => :inet.ip_address(),
          optional(:subnet) => :inet.ip_address(),
          optional(:timezone) => String.t(),
          optional(:router) => [:inet.ip_address()],
          optional(:dns) => [:inet.ip_address()],
          optional(:lprsrv) => [:inet.ip_address()],
          optional(:hostname) => String.t(),
          optional(:bootsize) => String.t(),
          optional(:domain) => String.t(),
          optional(:swapsrv) => :inet.ip_address(),
          optional(:rootpath) => String.t(),
          optional(:ipttl) => non_neg_integer(),
          optional(:mtu) => non_neg_integer(),
          optional(:broadcast) => :inet.ip_address(),
          optional(:routes) => [:inet.ip_address()],
          optional(:nisdomain) => String.t(),
          optional(:nissrv) => [:inet.ip_address()],
          optional(:ntpsrv) => [:inet.ip_address()],
          optional(:wins) => String.t(),
          optional(:lease) => non_neg_integer(),
          optional(:serverid) => :inet.ip_address(),
          optional(:message) => String.t(),
          optional(:renewal_time) => non_neg_integer(),
          optional(:rebind_time) => non_neg_integer(),
          optional(:vendor) => String.t(),
          optional(:tftp) => String.t(),
          optional(:bootfile) => String.t(),
          optional(:userclass) => String.t(),
          optional(:tzstr) => String.t(),
          optional(:tzdbstr) => String.t(),
          optional(:search) => String.t(),
          optional(:sipsrv) => String.t(),
          optional(:staticroutes) => [:inet.ip_address()],
          optional(:vlanid) => String.t(),
          optional(:vlanpriority) => non_neg_integer(),
          optional(:pxeconffile) => String.t(),
          optional(:pxepathprefix) => String.t(),
          optional(:reboottime) => String.t(),
          optional(:ip6rd) => String.t(),
          optional(:msstaticroutes) => String.t(),
          optional(:wpad) => String.t()
        }

  # Extract and translate udhcpc environment variables to DHCP options
  @doc false
  @spec udhcpc_to_options(%{String.t() => String.t()}) :: t()
  def udhcpc_to_options(info) do
    info
    |> Map.new(&transform_udhcpc_option/1)
    |> Map.delete(:discard)
  end

  # udhcpc passes DHCP options via environment variables and there's a lot of noise.
  # Transform known keys to atoms and mark unknown or unsupported ones as `:discard`
  defp transform_udhcpc_option({k, v}) do
    # See https://elixir.bootlin.com/busybox/1.35.0/source/networking/udhcp/common.c#L97
    # See https://www.rfc-editor.org/rfc/rfc2132 for descriptions
    udhcpc_option_map = %{
      # DHCP fields
      "ip" => {:ip, &IP.ip_to_tuple/1},
      "mask" => {:mask, &parse_int/1},
      "siaddr" => {:siaddr, &IP.ip_to_tuple/1},
      # DHCP options
      "subnet" => {:subnet, &IP.ip_to_tuple/1},
      "timezone" => {:timezone, &identity/1},
      "router" => {:router, &parse_ip_list/1},
      # "opt4" => :timesrv,
      # "opt5" => :namesrv,
      "dns" => {:dns, &parse_ip_list/1},
      # "opt7" => :logsrv,
      # "opt8" => :cookiesrv,
      "lprsrv" => {:lprsrv, &parse_ip_list/1},
      "hostname" => {:hostname, &identity/1},
      "bootsize" => {:bootsize, &identity/1},
      "domain" => {:domain, &identity/1},
      "swapsrv" => {:swapsrv, &IP.ip_to_tuple/1},
      "rootpath" => {:rootpath, &identity/1},
      "ipttl" => {:ipttl, &parse_int/1},
      "mtu" => {:mtu, &parse_int/1},
      "broadcast" => {:broadcast, &IP.ip_to_tuple/1},
      "routes" => {:routes, &parse_ip_list/1},
      "nisdomain" => {:nisdomain, &identity/1},
      "nissrv" => {:nissrv, &parse_ip_list/1},
      "ntpsrv" => {:ntpsrv, &parse_ip_list/1},
      "wins" => {:wins, &identity/1},
      "lease" => {:lease, &parse_int/1},
      "serverid" => {:serverid, &IP.ip_to_tuple/1},
      "message" => {:message, &identity/1},
      "opt58" => {:renewal_time, &parse_hex/1},
      "opt59" => {:rebind_time, &parse_hex/1},
      "vendor" => {:vendor, &identity/1},
      "tftp" => {:tftp, &identity/1},
      "bootfile" => {:bootfile, &identity/1},
      "opt77" => {:userclass, &identity/1},
      "tzstr" => {:tzstr, &identity/1},
      "tzdbstr" => {:tzdbstr, &identity/1},
      "search" => {:search, &identity/1},
      "sipsrv" => {:sipsrv, &identity/1},
      "staticroutes" => {:staticroutes, &parse_ip_list/1},
      "vlanid" => {:vlanid, &identity/1},
      "vlanpriority" => {:vlanpriority, &parse_int/1},
      "pxeconffile" => {:pxeconffile, &identity/1},
      "pxepathprefix" => {:pxepathprefix, &identity/1},
      "reboottime" => {:reboottime, &identity/1},
      "ip6rd" => {:ip6rd, &identity/1},
      "msstaticroutes" => {:msstaticroutes, &identity/1},
      "wpad" => {:wpad, &identity/1}
      # opt50 is used to request a client IP and used internally by udhcpc, so skip.
      # opt53 is the message type, so it's not an option
      # opt57 is the max message length, so it's not an option
      # See https://elixir.bootlin.com/busybox/1.35.0/source/networking/udhcp/common.c#L83
    }

    with {:ok, {key, parser}} <- Map.fetch(udhcpc_option_map, k),
         {:ok, result} <- parser.(v) do
      {key, result}
    else
      _error -> {:discard, nil}
    end
  end

  defp summarize_ok_tuples(ok_tuples, results \\ [])
  defp summarize_ok_tuples([], results), do: {:ok, Enum.reverse(results)}
  defp summarize_ok_tuples([{:ok, v} | rest], acc), do: summarize_ok_tuples(rest, [v | acc])
  defp summarize_ok_tuples([{:error, _} = error | _rest], _), do: error

  defp parse_ip_list(str) do
    str
    |> String.split(" ", trim: true)
    |> Enum.map(&IP.ip_to_tuple/1)
    |> summarize_ok_tuples()
  end

  defp parse_int(str) do
    case Integer.parse(str) do
      {v, ""} -> {:ok, v}
      _ -> {:error, "Expecting integer, got #{str}."}
    end
  end

  defp parse_hex(str) do
    case Integer.parse(str, 16) do
      {v, ""} -> {:ok, v}
      _ -> {:error, "Expecting hex, got #{str}."}
    end
  end

  defp identity(str), do: {:ok, str}
end
