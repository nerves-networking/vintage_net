defmodule VintageNet.IP.DhcpdConfig do
  @moduledoc """
  This is a helper module for VintageNet.Technology implementations that use
  a DHCP server.

  DHCP server parameters are:

  * `start` - Start of the lease block
  * `end` - End of the lease block
  * `max_leases` - The maximum number of leases
  * `decline_time` - The amount of time that an IP will be reserved (leased to nobody)
  * `conflict_time` -The amount of time that an IP will be reserved
  * `offer_time` - How long an offered address is reserved (seconds)
  * `min_lease` - If client asks for lease below this value, it will be rounded up to this value (seconds)
  * `auto_time` - The time period at which udhcpd will write out leases file.
  * `static_leases` - list of `{mac_address, ip_address}`
  """

  alias VintageNet.{Command, IP}
  alias VintageNet.Interface.RawConfig

  @doc """
  Normalize the DHCPD parameters in a configuration.
  """
  @spec normalize(map()) :: map()
  def normalize(%{dhcpd: dhcpd} = config) do
    # Normalize IP addresses
    new_dhcpd =
      dhcpd
      |> Map.update(:start, {192, 168, 0, 20}, &IP.ip_to_tuple!/1)
      |> Map.update(:end, {192, 168, 0, 254}, &IP.ip_to_tuple!/1)
      |> normalize_static_leases()
      |> Map.take([
        :start,
        :end,
        :max_leases,
        :decline_time,
        :conflict_time,
        :offer_time,
        :min_lease,
        :auto_time,
        :static_leases
      ])

    %{config | dhcpd: new_dhcpd}
  end

  def normalize(config), do: config

  defp normalize_static_leases(%{static_leases: leases} = dhcpd_config) do
    new_leases = Enum.map(leases, &normalize_lease/1)
    %{dhcpd_config | static_leases: new_leases}
  end

  defp normalize_static_leases(dhcpd_config), do: dhcpd_config

  defp normalize_lease({hwaddr, ipa}) do
    {hwaddr, IP.ip_to_tuple!(ipa)}
  end

  @doc """
  Add udhcpd configuration commands for running a DHCP server
  """
  @spec add_config(RawConfig.t(), map(), keyword()) :: RawConfig.t()
  def add_config(
        %RawConfig{
          ifname: ifname,
          files: files,
          child_specs: child_specs
        } = raw_config,
        %{dhcpd: dhcpd_config},
        opts
      ) do
    tmpdir = Keyword.fetch!(opts, :tmpdir)
    udhcpd = Keyword.fetch!(opts, :bin_udhcpd)
    udhcpd_conf_path = Path.join(tmpdir, "udhcpd.conf.#{ifname}")

    new_files =
      files ++
        [
          {udhcpd_conf_path, udhcpd_contents(ifname, dhcpd_config, tmpdir)}
        ]

    new_child_specs =
      child_specs ++
        [
          Supervisor.child_spec(
            {MuonTrap.Daemon,
             [
               udhcpd,
               [
                 "-f",
                 udhcpd_conf_path
               ],
               Command.add_muon_options(stderr_to_stdout: true, log_output: :debug)
             ]},
            id: :udhcpd
          )
        ]

    %RawConfig{raw_config | files: new_files, child_specs: new_child_specs}
  end

  def add_config(raw_config, _config_without_dhcpd, _opts), do: raw_config

  defp udhcpd_contents(ifname, dhcpd, tmpdir) do
    pidfile = Path.join(tmpdir, "udhcpd.#{ifname}.pid")
    lease_file = Path.join(tmpdir, "udhcpd.#{ifname}.leases")

    initial = """
    interface #{ifname}
    pidfile #{pidfile}
    lease_file #{lease_file}
    notify_file #{udhcpd_handler_path()}
    """

    config = Enum.map(dhcpd, &to_udhcpd_string/1)
    IO.iodata_to_binary([initial, "\n", config, "\n"])
  end

  defp to_udhcpd_string({:start, val}) do
    "start #{IP.ip_to_string(val)}\n"
  end

  defp to_udhcpd_string({:end, val}) do
    "end #{IP.ip_to_string(val)}\n"
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
      "static_lease #{mac} #{IP.ip_to_string(ip)}\n"
    end)
  end

  defp udhcpd_handler_path() do
    Application.app_dir(:vintage_net, ["priv", "udhcpd_handler"])
  end
end
