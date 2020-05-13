defmodule VintageNet.ActivityMonitor.Classifier do
  @moduledoc """
  TCP socket classifier

  This module takes information about a socket and classifies its connection
  so that the activity monitor can reason about it
  """

  alias VintageNet.ActivityMonitor.SocketInfo

  @typedoc """
  The type of socket:

  * `:local` - this goes to this computer (it's IP address is the same as an interface's IP address)
  * `:lan` - this socket connects to a computer on the LAN
  * `:internet` - this socket connects to a computer beyond the LAN (technically not necessarily the
     internet, but probably close enough for VintageNet's uses)
  """
  @type classification :: :local | :lan | :internet
  @type addresses :: [
          {VintageNet.ifname(),
           [
             %{
               address: :inet.address(),
               netmask: :inet.address()
             }
           ]}
        ]

  @doc """
  Classify the specified socket

  If information on this socket can be found, it returns the interface that the
  socket is using and whether the remote side is local, on the LAN, or beyond the
  first router.
  """
  @spec classify(SocketInfo.t(), addresses()) ::
          {:ok, VintageNet.ifname(), classification()} | {:error, :unknown}
  def classify(socket, addresses) do
    case find_interface(socket.local_address, addresses) do
      {ifname, address} ->
        {:ok, ifname, classify_destination(socket.foreign_address, address)}

      nil ->
        {:error, :unknown}
    end
  end

  # Go through the addresses to find which interface has the
  # specified ip and return the information about that IP so
  # that the caller can figure out subnet.
  defp find_interface({ip, _port}, addresses) do
    Enum.find_value(addresses, fn {ifname, if_addresses} ->
      has_matching_address(ip, if_addresses, ifname)
    end)
  end

  defp has_matching_address(ip, if_addresses, ifname) do
    case Enum.find(if_addresses, fn info -> info.address == ip end) do
      nil -> nil
      info -> {ifname, info}
    end
  end

  defp classify_destination({ip, _port}, address) do
    cond do
      ip == address.address -> :local
      in_subnet(ip, address.address, address.netmask) -> :lan
      true -> :internet
    end
  end

  # IPv4
  defp in_subnet({a, b, c, d}, {sa, sb, sc, sd}, {ma, mb, mc, md}) do
    same?(a, sa, ma) and same?(b, sb, mb) and same?(c, sc, mc) and same?(d, sd, md)
  end

  # IPv6
  defp in_subnet(
         {a, b, c, d, e, f, g, h},
         {sa, sb, sc, sd, se, sf, sg, sh},
         {ma, mb, mc, md, me, mf, mg, mh}
       ) do
    same?(a, sa, ma) and same?(b, sb, mb) and same?(c, sc, mc) and same?(d, sd, md) and
      same?(e, se, me) and same?(f, sf, mf) and same?(g, sg, mg) and same?(h, sh, mh)
  end

  defp same?(a, b, m) do
    :erlang.band(a, m) == :erlang.band(b, m)
  end
end
