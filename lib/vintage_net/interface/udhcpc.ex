defmodule VintageNet.Interface.Udhcpc do
  @behaviour VintageNet.ToElixir.UdhcpcHandler

  alias VintageNet.{NameResolver, RouteManager}

  require Logger

  @doc """
  """
  @impl true
  def deconfig(ifname, _info) do
    RouteManager.clear_route(ifname)

    # /sbin/ifconfig $interface up
    # /sbin/ifconfig $interface 0.0.0.0
    System.cmd("/sbin/ifconfig", [ifname, "up"])
    System.cmd("/sbin/ifconfig", [ifname, "0.0.0.0"])

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

  defp broadcast_args(%{broadcast: bcast}), do: ["broadcast", bcast]
  defp broadcast_args(_), do: []

  defp netmask_args(%{subnet: subnet}), do: ["netmask", subnet]
  defp netmask_args(_), do: []

  defp build_ifconfig_args(ifname, info) do
    [ifname, info.ip] ++ broadcast_args(info) ++ netmask_args(info)
  end

  @doc """
  """
  @impl true
  def renew(ifname, info) do
    Logger.debug("udhcpc.renew(#{ifname}): #{inspect(info)}")

    # [ -n "$broadcast" ] && BROADCAST="broadcast $broadcast"
    # [ -n "$subnet" ] && NETMASK="netmask $subnet"
    # if [ -x /usr/sbin/avahi-autoipd ]; then
    # 	/usr/sbin/avahi-autoipd -k $interface
    # fi
    # /sbin/ifconfig $interface $ip $BROADCAST $NETMASK

    ifconfig_args = build_ifconfig_args(ifname, info)
    System.cmd("/sbin/ifconfig", ifconfig_args)

    # if [ -n "$router" ] ; then
    # 	echo "deleting routers"
    # 	while route del default gw 0.0.0.0 dev $interface 2> /dev/null; do
    # 		:
    # 	done

    # 	for i in $router ; do
    # 		route add default gw $i dev $interface
    # 	done
    # fi
    case info[:router] do
      routers when is_list(routers) ->
        first_router = hd(routers)
        {:ok, addr} = :inet.parse_address(to_charlist(first_router))

        RouteManager.set_route(ifname, addr, :lan)

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
