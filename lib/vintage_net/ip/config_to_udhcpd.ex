defmodule VintageNet.IP.ConfigToUdhcpd do
  @moduledoc """
  This is a helper module for VintageNet.Technology implementations that use
  the udhcpd server.
  """

  @doc """
  Convert a configuration to the contents of a /etc/udhcpd.conf file

  `start` - Start of the lease block
  `end` - End of the lease block
  `max_leases` - The maximum number of leases
  `decline_time` - The amount of time that an IP will be reserved (leased to nobody)
  `conflict_time` -The amount of time that an IP will be reserved
  `offer_time` - How long an offered address is reserved (seconds)
  `min_lease` - If client asks for lease below this value, it will be rounded up to this value (seconds)
  `auto_time` - The time period at which udhcpd will write out leases file.
  `static_leases` - list of `{macaddress, ipaddress}`
  """
  @spec config_to_udhcpd_contents(VintageNet.ifname(), map(), Path.t()) :: String.t()
  def config_to_udhcpd_contents(ifname, %{dhcpd: dhcpd}, tmpdir) do
    pidfile = Path.join(tmpdir, "udhcpd.#{ifname}.pid")
    lease_file = Path.join(tmpdir, "udhcpd.#{ifname}.leases")

    initial = """
    interface #{ifname}
    pidfile #{pidfile}
    lease_file #{lease_file}
    notify_file #{udhcpd_handler_path(tmpdir, ifname)}
    """

    config = Enum.map(dhcpd, &to_udhcpd_string/1)
    IO.iodata_to_binary([initial, "\n", config, "\n"])
  end

  defp to_udhcpd_string({:start, val}) do
    "start #{val}\n"
  end

  defp to_udhcpd_string({:end, val}) do
    "end #{val}\n"
  end

  defp to_udhcpd_string({:max_leases, val}) do
    "max_leases #{val}\n"
  end

  defp to_udhcpd_string({:decline_time, val}) do
    "decline_time #{val}\n"
  end

  defp to_udhcpd_string({:conflict_time, val}) do
    "conflict_time #{val}\n"
  end

  defp to_udhcpd_string({:offer_time, val}) do
    "offer_time #{val}\n"
  end

  defp to_udhcpd_string({:min_lease, val}) do
    "min_lease #{val}\n"
  end

  defp to_udhcpd_string({:auto_time, val}) do
    "auto_time #{val}\n"
  end

  defp to_udhcpd_string({:static_leases, leases}) do
    Enum.map(leases, fn {mac, ip} ->
      "static_lease #{mac} #{ip}\n"
    end)
  end

  defp udhcpd_handler_path(tmpdir, ifname) do
    from = Application.app_dir(:vintage_net, ["priv", "udhcpd_handler"])
    to = Path.join(tmpdir, "udhcpd.#{ifname}.udhcpd_handler")
    _ = File.ln_s(from, to)
    to
  end
end
