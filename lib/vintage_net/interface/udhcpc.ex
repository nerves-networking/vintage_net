defmodule VintageNet.Interface.Udhcpc do
  @behaviour VintageNet.ToElixir.UdhcpcHandler

  alias VintageNet.{Command, InterfacesMonitor, NameResolver, RouteManager}

  require Logger

  @doc """
  """
  @impl true
  def deconfig(ifname, info) do
    _ = Logger.info("#{ifname} dhcp deconfig: #{inspect(info)}")

    # If there were any IPv4 addresses reported on this interface, remove them
    # now. They may not be reported by the normal mechanism from the
    # `InterfacesMonitor` and were observed to no tbe reported when the
    # GenServer running `udhcpc` was restarted.
    InterfacesMonitor.force_clear_ipv4_addresses(ifname)

    RouteManager.clear_route(ifname)

    # /sbin/ifconfig $interface up
    # /sbin/ifconfig $interface 0.0.0.0
    _ = Command.cmd(:bin_ifconfig, [ifname, "up"])
    _ = Command.cmd(:bin_ifconfig, [ifname, "0.0.0.0"])

    # # drop info from this interface
    # # resolv.conf may be a symlink to /tmp/, so take care
    # TMPFILE=$(mktemp)
    # grep -vE "# $interface\$" $RESOLV_CONF > $TMPFILE
    # cat $TMPFILE > $RESOLV_CONF
    # rm -f $TMPFILE
    NameResolver.clear(ifname)

    # if [ -x /usr/sbin/avahi-autoipd ]; then
    # 	/usr/sbin/avahi-autoipd -k $interface
    # fi

    :ok
  end

  @doc """
  """
  @impl true
  def leasefail(ifname, _info) do
    # NOTE: This message tends to clog up logs, so be careful when enabling it.

    # _ = Logger.info("#{ifname} dhcp leasefail: #{inspect(info)}")
    RouteManager.clear_route(ifname)
    # if [ -x /usr/sbin/avahi-autoipd ]; then
    # 	/usr/sbin/avahi-autoipd -wD $interface --no-chroot
    # fi
    :ok
  end

  @doc """
  """
  @impl true
  def nak(ifname, info) do
    leasefail(ifname, info)
    :ok
  end

  defp broadcast_args(%{broadcast: broadcast}), do: ["broadcast", broadcast]
  defp broadcast_args(_), do: []

  defp netmask_args(%{subnet: subnet}), do: ["netmask", subnet]
  defp netmask_args(_), do: []

  defp build_ifconfig_args(ifname, info) do
    [ifname, info.ip] ++ broadcast_args(info) ++ netmask_args(info)
  end

  defp ip_subnet(%{ip: address, mask: mask}) do
    {:ok, our_ip} = :inet.parse_address(to_charlist(address))
    {our_ip, String.to_integer(mask)}
  end

  @doc """
  """
  @impl true
  def renew(ifname, info) do
    _ = Logger.debug("udhcpc.renew(#{ifname}): #{inspect(info)}")

    # [ -n "$broadcast" ] && BROADCAST="broadcast $broadcast"
    # [ -n "$subnet" ] && NETMASK="netmask $subnet"
    # if [ -x /usr/sbin/avahi-autoipd ]; then
    # 	/usr/sbin/avahi-autoipd -k $interface
    # fi
    # /sbin/ifconfig $interface $ip $BROADCAST $NETMASK

    ifconfig_args = build_ifconfig_args(ifname, info)
    _ = Command.cmd(:bin_ifconfig, ifconfig_args)

    case info[:router] do
      routers when is_list(routers) ->
        ip_subnet = ip_subnet(info)

        first_router = hd(routers)
        {:ok, default_gateway} = :inet.parse_address(to_charlist(first_router))

        RouteManager.set_route(ifname, [ip_subnet], default_gateway, :lan)

      nil ->
        :ok
    end

    # # drop info from this interface
    # # resolv.conf may be a symlink to /tmp/, so take care
    # TMPFILE=$(mktemp)
    # grep -vE "# $interface\$" $RESOLV_CONF > $TMPFILE
    # cat $TMPFILE > $RESOLV_CONF
    # rm -f $TMPFILE

    # # prefer rfc3359 domain search list (option 119) if available
    # if [ -n "$search" ]; then
    # 	search_list=$search
    # elif [ -n "$domain" ]; then
    # 	search_list=$domain
    # fi
    # [ -n "$search_list" ] &&
    # 	echo "search $search_list # $interface" >> $RESOLV_CONF

    domain =
      cond do
        Map.has_key?(info, :search) ->
          # prefer rfc3359 domain search list (option 119) if available
          Map.get(info, :search)

        Map.has_key?(info, :domain) ->
          Map.get(info, :domain)

        true ->
          ""
      end

    # for i in $dns ; do
    # 	echo adding dns $i
    # 	echo "nameserver $i # $interface" >> $RESOLV_CONF
    # done
    dns = Map.get(info, :dns, [])

    NameResolver.setup(ifname, domain, dns)
    :ok
  end

  @doc """
  """
  @impl true
  def bound(ifname, info) do
    renew(ifname, info)
    :ok
  end
end
