defmodule VintageNet.Interface.Udhcpd do
  @moduledoc false

  @behaviour VintageNet.OSEventDispatcher.UdhcpdHandler
  require Logger

  @impl VintageNet.OSEventDispatcher.UdhcpdHandler
  def lease_update(ifname, lease_file) do
    case parse_leases(lease_file) do
      {:ok, leases} ->
        PropertyTable.put(VintageNet, ["interface", ifname, "dhcpd", "leases"], leases)

      {:error, _} ->
        Logger.error("#{ifname}: Failed to handle lease update from #{lease_file}")

        PropertyTable.delete_matches(VintageNet, ["interface", ifname, "dhcpd", "leases"])
    end
  end

  @doc """
  Parse the leases file from udhcpd
  """
  @spec parse_leases(Path.t()) :: {:ok, [map()]} | {:error, File.posix()}
  def parse_leases(path) do
    with {:ok, <<_timestamp::binary-size(8), rest::binary>>} <- File.read(path) do
      do_parse_leases(rest, [])
    end
  end

  defp do_parse_leases(
         <<leasetime::unsigned-integer-size(32), ip1, ip2, ip3, ip4, mac1, mac2, mac3, mac4, mac5,
           mac6, hostname::binary-size(20), _pad::binary-size(2), rest::binary>>,
         acc
       ) do
    lease = %{
      leasetime: leasetime,
      lease_nip: Enum.join([ip1, ip2, ip3, ip4], "."),
      lease_mac:
        Enum.join(
          [
            Integer.to_string(mac1, 16),
            Integer.to_string(mac2, 16),
            Integer.to_string(mac3, 16),
            Integer.to_string(mac4, 16),
            Integer.to_string(mac5, 16),
            Integer.to_string(mac6, 16)
          ],
          ":"
        ),
      hostname: String.trim(hostname, <<0>>)
    }

    do_parse_leases(rest, [lease | acc])
  end

  defp do_parse_leases(<<>>, acc), do: {:ok, acc}
end
