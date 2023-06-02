defmodule VintageNet.Connectivity.Inspector do
  @moduledoc """
  This module looks at the network activity of all TCP socket connections known
  to Erlang/OTP to deduce whether the internet is working.

  To use it, call `check_internet/2`, save the returned cache, and then call it
  again a minute later (or so). If any socket has transferred data in both
  directions to an off-LAN host on the interface of interest, then it will
  return that the internet is available.

  This has a couple advantages:

  1. No data is sent to perform the check which is good for metered connections
  2. Most long-lived TCP connections have a keepalive mechanism that generates
     traffic, so this piggy-backs off that existing connectivity check.
  3. Devices can be behind very restrictive firewalls and internet connectivity
     can still be verified without knowing which IP/port/protocol combinations
     are allowed.

  It is not perfect:

  1. It only works on long-lived TCP connections.
  2. The TCP connection must be sending and receiving data. If the keapalive is
     longer than the `check_internet/2`
  3. It doesn't help if nobody is using the network interface.
  4. It may have scalability issues if there are a LOT of TCP sockets.
  """

  @typedoc """
  Cache for use between `check_internet/2` calls. Initialize to an empty map.
  """
  @type cache() :: %{port() => {non_neg_integer(), non_neg_integer()}}

  @typedoc """
  Internet connectivity status

    * `:internet` - the internet is available
    * `:unknown` - not sure
    * `:no_internet` - the internet is definitely not available
  """
  @type status() :: :internet | :unknown | :no_internet

  @typedoc """
  The return tuple for `check_internet/2`

  * `:internet` - at least one TCP connection sent and received data to a
    non-LAN IP address
  * `:unknown` - no conclusion could be made
  * `:no_internet` - the interface didn't have an IP address, so Internet is
    definitely not available

  Save the cache away and pass it to the next call to `check_internet/2`.
  """
  @type result() :: {status(), cache()}

  @typep ip_address_and_mask() :: {:inet.ip_address(), :inet.ip_address()}

  @doc """
  Check whether the internet is accessible on the specified interface

  Pass an empty map for the cache parameter for the first call. Then pass it
  back the returned cache for each subsequent call. If any TCP socket that's
  connected to a computer on another subnet and that's using the passed in
  network interface has send AND received data since the previous call, then
  `:internet` is returned. If not, then usually `:unknown` is returned to
  signify that internet may be available, but we just don't know. If the
  interface doesn't have an IP address, then `:no_internet` is returned, since
  that's a prerequisite to communicating with anyone on the internet.
  """
  @spec check_internet(VintageNet.ifname(), cache()) :: result()
  def check_internet(ifname, cache) do
    case get_addresses(ifname) do
      [] ->
        # If we don't even have an IP address, then there's no Internet for sure.
        {:no_internet, %{}}

      our_addresses ->
        {:unknown, %{}}
        |> check_ports(Port.list(), our_addresses, cache)
        |> check_sockets(:socket.which_sockets(:tcp), our_addresses, cache)
    end
  end

  @doc """
  Returns true if the specified address is not on the network interface

  This function is useful for checking whether an address is on the Internet if
  you don't trust the DNS server. Captive portals, for example, can give back
  IP addresses that are local. It's not guaranteed, but it would be pointless to
  check those IP's if you're looking for the Internet.
  """
  @spec routed_address?(VintageNet.ifname(), :inet.ip_address()) :: boolean()
  def routed_address?(ifname, ip_address) do
    case get_addresses(ifname) do
      [] ->
        # If we don't even have an IP address, then there's no Internet for sure.
        false

      our_addresses ->
        not on_interface?(ip_address, our_addresses)
    end
  end

  @doc false
  @spec check_ports(result(), [port()], [ip_address_and_mask()], cache()) :: result()
  def check_ports(result, [], _our_addresses, _cache), do: result

  def check_ports(result, [socket | rest], our_addresses, cache) do
    new_result =
      case Map.fetch(cache, socket) do
        {:ok, previous_stats} ->
          new_stats = get_port_stats(socket)
          update_result(result, socket, previous_stats, new_stats)

        _ ->
          check_new_port(socket, our_addresses, result)
      end

    check_ports(new_result, rest, our_addresses, cache)
  end

  defp get_port_stats(socket) when is_port(socket) do
    case :inet.getstat(socket, [:send_oct, :recv_oct]) do
      {:ok, [send_oct: tx, recv_oct: rx]} ->
        {tx, rx}

      {:ok, [recv_oct: rx, send_oct: tx]} ->
        {tx, rx}

      {:error, _} ->
        # Race condition. Socket was in the list, but by the time it was
        # checked, it was closed. No big deal. It will be removed from the
        # cache next time. Return bogus values that definitely won't update the
        # result to indicate Internet availability.
        {0, 0}
    end
  end

  @doc false
  @spec check_sockets(result(), [:socket.socket()], [ip_address_and_mask()], cache()) :: result()
  def check_sockets(result, [], _our_addresses, _cache), do: result

  def check_sockets(result, [socket | rest], our_addresses, cache) do
    new_result =
      case Map.fetch(cache, socket) do
        {:ok, previous_stats} ->
          new_stats = get_socket_stats(socket)
          update_result(result, socket, previous_stats, new_stats)

        _ ->
          check_new_socket(socket, our_addresses, result)
      end

    check_sockets(new_result, rest, our_addresses, cache)
  end

  defp get_socket_stats(socket) do
    # Socket API
    %{counters: %{write_byte: tx, read_byte: rx}} = :socket.info(socket)
    {tx, rx}
  end

  defp update_result({:unknown, cache}, socket, {tx1, rx1}, {tx2, rx2} = new_stats)
       when tx2 > tx1 and rx2 > rx1 do
    {:internet, Map.put(cache, socket, new_stats)}
  end

  defp update_result({status, cache}, socket, _previous_stats, new_stats) do
    {status, Map.put(cache, socket, new_stats)}
  end

  defp check_new_port(socket, our_addresses, {status, cache}) do
    with {:name, ~c"tcp_inet"} <- Port.info(socket, :name),
         true <- connected?(socket),
         {:ok, {src_ip, _src_port}} <- :inet.sockname(socket),
         true <- on_interface?(src_ip, our_addresses),
         {:ok, {dest_ip, _dest_port}} <- :inet.peername(socket),
         false <- on_interface?(dest_ip, our_addresses) do
      {status, Map.put(cache, socket, get_port_stats(socket))}
    else
      _ -> {status, cache}
    end
  end

  defp connected?(socket) do
    case :prim_inet.getstatus(socket) do
      {:ok, status} -> :connected in status
      _ -> false
    end
  end

  defp check_new_socket(socket, our_addresses, {status, cache}) do
    # Socket API
    with %{protocol: :tcp, counters: %{write_byte: tx, read_byte: rx}} <- :socket.info(socket),
         {:ok, %{addr: src_ip}} <- :socket.sockname(socket),
         true <- on_interface?(src_ip, our_addresses),
         {:ok, %{addr: dest_ip}} <- :socket.peername(socket),
         false <- on_interface?(dest_ip, our_addresses) do
      {status, Map.put(cache, socket, {tx, rx})}
    else
      _ -> {status, cache}
    end
  end

  @doc """
  Return true if an IP address is on one of the subnets in a list
  """
  @spec on_interface?(:inet.ip_address(), [ip_address_and_mask()]) :: boolean
  def on_interface?(_ip, []), do: false

  def on_interface?(ip, [one_address | rest]) do
    on_subnet?(ip, one_address) || on_interface?(ip, rest)
  end

  @doc """
  Return true if an IP address is in the subnet

  ## Examples

      iex> Inspector.on_subnet?({192,168,0,50}, {{192,168,0,1}, {255,255,255,0}})
      true

      iex> Inspector.on_subnet?({192,168,5,1}, {{192,168,0,1}, {255,255,255,0}})
      false
  """
  @spec on_subnet?(:inet.ip_address(), ip_address_and_mask()) :: boolean
  def on_subnet?({a, b, c, d}, {{sa, sb, sc, sd}, {ma, mb, mc, md}}) do
    :erlang.band(:erlang.bxor(a, sa), ma) == 0 and
      :erlang.band(:erlang.bxor(b, sb), mb) == 0 and
      :erlang.band(:erlang.bxor(c, sc), mc) == 0 and
      :erlang.band(:erlang.bxor(d, sd), md) == 0
  end

  def on_subnet?(
        {a, b, c, d, e, f, g, h},
        {{sa, sb, sc, sd, se, sf, sg, sh}, {ma, mb, mc, md, me, mf, mg, mh}}
      ) do
    :erlang.band(:erlang.bxor(a, sa), ma) == 0 and
      :erlang.band(:erlang.bxor(b, sb), mb) == 0 and
      :erlang.band(:erlang.bxor(c, sc), mc) == 0 and
      :erlang.band(:erlang.bxor(d, sd), md) == 0 and
      :erlang.band(:erlang.bxor(e, se), me) == 0 and
      :erlang.band(:erlang.bxor(f, sf), mf) == 0 and
      :erlang.band(:erlang.bxor(g, sg), mg) == 0 and
      :erlang.band(:erlang.bxor(h, sh), mh) == 0
  end

  def on_subnet?(_ip, {_subnet_ip, _subnet_mask}) do
    false
  end

  @doc false
  @spec get_addresses(VintageNet.ifname()) :: [ip_address_and_mask()]
  def get_addresses(ifname) do
    with {:ok, interfaces} <- :inet.getifaddrs(),
         {_, info} <- List.keyfind(interfaces, to_charlist(ifname), 0, []) do
      extract_addr_mask(info, [])
    else
      _ ->
        []
    end
  end

  defp extract_addr_mask([], acc), do: acc

  defp extract_addr_mask([{:addr, a}, {:netmask, m} | rest], acc),
    do: extract_addr_mask(rest, [{a, m} | acc])

  defp extract_addr_mask([_ | rest], acc), do: extract_addr_mask(rest, acc)
end
