defmodule VintageNet.Interface.Udhcpc do
  @behaviour VintageNet.ToElixir.UdhcpcHandler

  alias VintageNet.Interface.Resolvconf

  require Logger

  @doc """
  """
  @impl true
  def deconfig(ifname, info) do
    # /sbin/ifconfig $interface up
    # /sbin/ifconfig $interface 0.0.0.0

    # # drop info from this interface
    # # resolv.conf may be a symlink to /tmp/, so take care
    # TMPFILE=$(mktemp)
    # grep -vE "# $interface\$" $RESOLV_CONF > $TMPFILE
    # cat $TMPFILE > $RESOLV_CONF
    # rm -f $TMPFILE
    Resolvconf.clear(ifname)

    # if [ -x /usr/sbin/avahi-autoipd ]; then
    # 	/usr/sbin/avahi-autoipd -k $interface
    # fi

    :ok
  end

  @doc """
  """
  @impl true
  def leasefail(ifname, info) do
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

  @doc """
  """
  @impl true
  def renew(ifname, info) do
    # if [ -x /usr/sbin/avahi-autoipd ]; then
    # 	/usr/sbin/avahi-autoipd -k $interface
    # fi
    # /sbin/ifconfig $interface $ip $BROADCAST $NETMASK

    # if [ -n "$router" ] ; then
    # 	echo "deleting routers"
    # 	while route del default gw 0.0.0.0 dev $interface 2> /dev/null; do
    # 		:
    # 	done

    # 	for i in $router ; do
    # 		route add default gw $i dev $interface
    # 	done
    # fi

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

    # for i in $dns ; do
    # 	echo adding dns $i
    # 	echo "nameserver $i # $interface" >> $RESOLV_CONF
    # done

    Resolvconf.setup(ifname, info.domain, info.dns)
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
