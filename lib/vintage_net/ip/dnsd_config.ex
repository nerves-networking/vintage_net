defmodule VintageNet.IP.DnsdConfig do
  @moduledoc """
  This is a helper module for VintageNet.Technology implementations that use
  the Busybox DNS server.

  DNS functionality is only supported for IPv4 configurations using static IP
  addresses.

  DNS server parameters are:

  * `:port` - The port to use (defaults to 53)
  * `:ttl` - DNS record TTL in seconds (defaults to 120)
  * `:records` - DNS A records (required)

  The `:records` option is a list of name/IP address tuples. For example:

  ```
  [{"example.com", {1, 2, 3, 4}}]
  ```

  Only IPv4 addresses are supported. Addresses may be specified as strings or
  tuples, but will be normalized to tuple form before being applied.
  """

  alias VintageNet.{Command, IP}
  alias VintageNet.Interface.RawConfig

  @doc """
  Normalize the DNSD parameters in a configuration.
  """
  @spec normalize(map()) :: map()
  def normalize(%{ipv4: %{method: :static}, dnsd: dnsd} = config) do
    # Normalize IP addresses
    new_dnsd =
      dnsd
      |> Map.update(:records, [], &normalize_records/1)
      |> Map.take([
        :records,
        :port,
        :ttl
      ])

    %{config | dnsd: new_dnsd}
  end

  def normalize(%{dnsd: _something_else} = config) do
    # DNSD won't be started if not an IPv4 static configuration
    Map.drop(config, [:dnsd])
  end

  def normalize(config), do: config

  defp normalize_records(records) do
    Enum.map(records, &normalize_record/1)
  end

  defp normalize_record({name, ipa}) do
    {name, IP.ip_to_tuple!(ipa)}
  end

  @doc """
  Add dnsd configuration commands for running a DNSD server
  """
  @spec add_config(RawConfig.t(), map(), keyword()) :: RawConfig.t()
  def add_config(
        %RawConfig{
          ifname: ifname,
          files: files,
          child_specs: child_specs
        } = raw_config,
        %{ipv4: %{method: :static, address: address}, dnsd: dnsd_config},
        opts
      ) do
    tmpdir = Keyword.fetch!(opts, :tmpdir)
    dnsd_conf_path = Path.join(tmpdir, "dnsd.conf.#{ifname}")

    new_files = [{dnsd_conf_path, dnsd_contents(dnsd_config)} | files]

    dnsd_args =
      [
        "-c",
        dnsd_conf_path,
        "-i",
        IP.ip_to_string(address)
      ]
      |> add_port(dnsd_config)
      |> add_ttl(dnsd_config)

    new_child_specs =
      child_specs ++
        [
          Supervisor.child_spec(
            {MuonTrap.Daemon,
             [
               "dnsd",
               dnsd_args,
               Command.add_muon_options(stderr_to_stdout: true, log_output: :debug)
             ]},
            id: :dnsd
          )
        ]

    %RawConfig{raw_config | files: new_files, child_specs: new_child_specs}
  end

  def add_config(raw_config, _config_without_dhcpd, _opts), do: raw_config

  defp dnsd_contents(%{records: records}) do
    Enum.map(records, &record_to_string/1)
    |> IO.chardata_to_string()
  end

  defp record_to_string({name, ipa}) do
    "#{name} #{IP.ip_to_string(ipa)}\n"
  end

  defp add_port(dnsd_args, %{port: port}) do
    ["-p", to_string(port) | dnsd_args]
  end

  defp add_port(dnsd_args, _dnsd_config), do: dnsd_args

  defp add_ttl(dnsd_args, %{ttl: ttl}) do
    ["-t", to_string(ttl) | dnsd_args]
  end

  defp add_ttl(dnsd_args, _dnsd_config), do: dnsd_args
end
