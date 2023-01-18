defmodule VintageNet.Interface.Udhcpc do
  @moduledoc false
  @behaviour VintageNet.OSEventDispatcher.UdhcpcHandler

  alias VintageNet.Command
  alias VintageNet.DHCP.Options
  alias VintageNet.InterfacesMonitor
  alias VintageNet.IP
  alias VintageNet.NameResolver
  alias VintageNet.RouteManager

  require Logger

  @doc """
  Handle deconfig reports from udhcpc
  """
  @impl VintageNet.OSEventDispatcher.UdhcpcHandler
  def deconfig(ifname, info) do
    Logger.info("#{ifname} dhcp deconfig: #{inspect(info)}")

    # If there were any IPv4 addresses reported on this interface, remove them
    # now. They may not be reported by the normal mechanism from the
    # `InterfacesMonitor` and were observed to no tbe reported when the
    # GenServer running `udhcpc` was restarted.
    InterfacesMonitor.force_clear_ipv4_addresses(ifname)

    RouteManager.clear_route(ifname)

    # /sbin/ifconfig $interface up
    # /sbin/ifconfig $interface 0.0.0.0
    _ = Command.cmd("ifconfig", [ifname, "up"])
    _ = Command.cmd("ifconfig", [ifname, "0.0.0.0"])

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
  Handle leasefail reports from udhcpc
  """
  @impl VintageNet.OSEventDispatcher.UdhcpcHandler
  def leasefail(ifname, _info) do
    # NOTE: This message tends to clog up logs, so be careful when enabling it.

    # Logger.info("#{ifname} dhcp leasefail: #{inspect(info)}")
    RouteManager.clear_route(ifname)
    # if [ -x /usr/sbin/avahi-autoipd ]; then
    # 	/usr/sbin/avahi-autoipd -wD $interface --no-chroot
    # fi
    :ok
  end

  @doc """
  Handle nak reports from udhcpc
  """
  @impl VintageNet.OSEventDispatcher.UdhcpcHandler
  def nak(ifname, info) do
    leasefail(ifname, info)
  end

  defp broadcast_args(%{broadcast: broadcast}), do: ["broadcast", IP.ip_to_string(broadcast)]
  defp broadcast_args(_), do: []

  defp netmask_args(%{subnet: subnet}), do: ["netmask", IP.ip_to_string(subnet)]
  defp netmask_args(_), do: []

  @doc false
  @spec ifconfig_args(VintageNet.ifname(), Options.t()) :: [String.t()]
  def ifconfig_args(ifname, info) do
    [ifname, IP.ip_to_string(info.ip)] ++ broadcast_args(info) ++ netmask_args(info)
  end

  @doc """
  Handle renew reports from udhcpc
  """
  @impl VintageNet.OSEventDispatcher.UdhcpcHandler
  def renew(ifname, info) do
    Logger.debug("udhcpc.renew(#{ifname}): #{inspect(info)}")

    # [ -n "$broadcast" ] && BROADCAST="broadcast $broadcast"
    # [ -n "$subnet" ] && NETMASK="netmask $subnet"
    # if [ -x /usr/sbin/avahi-autoipd ]; then
    # 	/usr/sbin/avahi-autoipd -k $interface
    # fi
    # /sbin/ifconfig $interface $ip $BROADCAST $NETMASK

    _ = Command.cmd("ifconfig", ifconfig_args(ifname, info))

    case info[:router] do
      [default_gateway | _rest] ->
        ip_subnet = {info.ip, info.mask}

        RouteManager.set_route(ifname, [ip_subnet], default_gateway)

      _ ->
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
  Handle bound reports from udhcpc
  """
  @impl VintageNet.OSEventDispatcher.UdhcpcHandler
  def bound(ifname, info) do
    renew(ifname, info)
  end
end
