defmodule VintageNet.IP.DhcpdConfig do
  @moduledoc """
  This is a helper module for VintageNet.Technology implementations that use
  a DHCP server.

  DHCP server parameters are:

  * `:start` - Start of the lease block
  * `:end` - End of the lease block
  * `:max_leases` - The maximum number of leases
  * `:decline_time` - The amount of time that an IP will be reserved (leased to nobody)
  * `:conflict_time` -The amount of time that an IP will be reserved
  * `:offer_time` - How long an offered address is reserved (seconds)
  * `:min_lease` - If client asks for lease below this value, it will be rounded up to this value (seconds)
  * `:auto_time` - The time period at which udhcpd will write out leases file.
  * `:static_leases` - list of `{mac_address, ip_address}`
  * `:options` - a map DHCP response options to set. Such as:
    * `:dns` - IP_LIST
    * `:domain` -  STRING - [0x0f] client's domain suffix
    * `:hostname` - STRING
    * `:mtu` - NUM
    * `:router` - IP_LIST
    * `:search` - STRING_LIST - [0x77] search domains
    * `:serverid` - IP (defaults to the interface's IP address)
    * `:subnet` or `:netmask` - IP as a subnet mask (`:netmask` is an alias for `:subnet`)

  > #### :options {: .info}
  > Options may also be passed in as integers. These are passed directly to the DHCP server
  > and their values are strings that are not interpreted by VintageNet. Use this to support
  > custom DHCP header options. For more details on DHCP response options see RFC 2132

  ## Example
  ```
    VintageNet.configure("wlan0", %{
      type: VintageNetWiFi,
      vintage_net_wifi: %{
        networks: [
          %{
            mode: :ap,
            ssid: "test ssid",
            key_mgmt: :none
          }
        ]
      },
      dhcpd: %{
        start: "192.168.24.2",
        end: "192.168.24.10",
        options: %{
          dns: ["1.1.1.1", "1.0.0.1"],
          netmask: "255.255.255.0",
          router: ["192.168.24.1"]
        }
      }
    })
  ```
  """

  alias VintageNet.{Command, IP}
  alias VintageNet.Interface.RawConfig

  @ip_list_options [:dns, :router]
  @ip_options [:serverid, :subnet]
  @int_options [:mtu]
  @string_options [:hostname, :domain]
  @string_list_options [:search]
  @list_options @ip_list_options ++ @string_list_options

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
      |> normalize_options()
      |> Map.take([
        :start,
        :end,
        :max_leases,
        :decline_time,
        :conflict_time,
        :offer_time,
        :min_lease,
        :auto_time,
        :static_leases,
        :options
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

  defp normalize_options(%{options: options} = dhcpd_config) do
    new_options = for option <- options, into: %{}, do: normalize_option(option)
    %{dhcpd_config | options: new_options}
  end

  defp normalize_options(dhcpd_config), do: dhcpd_config

  # Support :netmask as an alias to :subnet in v0.13.2. This makes
  # the configuration more consistent with `:ipv4` options.
  defp normalize_option({:netmask, ip}), do: normalize_option({:subnet, ip})

  defp normalize_option({ip_option, ip})
       when ip_option in @ip_options do
    {ip_option, IP.ip_to_tuple!(ip)}
  end

  defp normalize_option({ip_list_option, ip_list})
       when ip_list_option in @ip_list_options and is_list(ip_list) do
    {ip_list_option, Enum.map(ip_list, &IP.ip_to_tuple!/1)}
  end

  defp normalize_option({string_list_option, string_list})
       when string_list_option in @string_list_options and is_list(string_list) do
    {string_list_option, Enum.map(string_list, &to_string/1)}
  end

  defp normalize_option({list_option, one_item})
       when list_option in @list_options and not is_list(one_item) do
    # Fix super-easy mistake of not passing a list when there's only one item
    normalize_option({list_option, [one_item]})
  end

  defp normalize_option({int_option, value})
       when int_option in @int_options and
              is_integer(value) do
    {int_option, value}
  end

  defp normalize_option({string_option, string})
       when string_option in @string_options do
    {string_option, to_string(string)}
  end

  defp normalize_option({other_option, string})
       when is_integer(other_option) and is_binary(string) do
    {other_option, to_string(string)}
  end

  defp normalize_option({bad_option, _value}) do
    raise ArgumentError,
          "Unknown dhcpd option '#{bad_option}'. Options unknown to VintageNet can be passed in as integers."
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
               "udhcpd",
               [
                 "-f",
                 udhcpd_conf_path
               ],
               Command.add_muon_options(
                 stderr_to_stdout: true,
                 log_output: :debug,
                 env: BEAMNotify.env(name: "vintage_net_comm", report_env: true)
               )
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
    notify_file #{BEAMNotify.bin_path()}
    """

    config = dhcpd |> Enum.sort() |> Enum.map(&to_udhcpd_string/1)
    IO.chardata_to_string([initial, "\n", config, "\n"])
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

  defp to_udhcpd_string({:options, options}) do
    sorted_options = Enum.sort(options)

    for option <- sorted_options do
      ["opt ", to_udhcpd_option_string(option), "\n"]
    end
  end

  defp to_udhcpd_option_string({option, ip}) when option in @ip_options do
    [to_string(option), " ", IP.ip_to_string(ip)]
  end

  defp to_udhcpd_option_string({option, ip_list}) when option in @ip_list_options do
    [to_string(option), " " | ip_list_to_iodata(ip_list)]
  end

  defp to_udhcpd_option_string({option, string_list}) when option in @string_list_options do
    [to_string(option), " " | Enum.intersperse(string_list, " ")]
  end

  defp to_udhcpd_option_string({option, value}) when option in @int_options do
    [to_string(option), " ", to_string(value)]
  end

  defp to_udhcpd_option_string({option, string}) when option in @string_options do
    [to_string(option), " ", string]
  end

  defp to_udhcpd_option_string({other_option, string}) when is_integer(other_option) do
    [to_string(other_option), " ", string]
  end

  defp ip_list_to_iodata(ip_list) do
    ip_list
    |> Enum.map(&IP.ip_to_string/1)
    |> Enum.intersperse(" ")
  end
end
