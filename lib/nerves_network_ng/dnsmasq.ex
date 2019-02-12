defmodule Nerves.NetworkNG.DNSMASQ do
  alias Nerves.NetworkNG

  @type t :: %__MODULE__{}

  defstruct interface: "wlan0",
            listen_address: nil,
            bind_interfaces: true,
            server: "8.8.8.8",
            domain_needed: true,
            bogus_priv: true,
            dhcp_range_min: nil,
            dhcp_range_max: nil,
            lease_time_hours: 12

  def new(interface, listen_address, dhcp_range_min, dhcp_range_max, opts \\ []) do
    opts =
      [
        interface: interface,
        listen_address: listen_address,
        dhcp_range_min: dhcp_range_min,
        dhcp_range_max: dhcp_range_max
      ]
      |> Keyword.merge(opts)

    struct(__MODULE__, opts)
  end

  def config_file_path() do
    tmp_dir = NetworkNG.tmp_dir()
    Path.join(tmp_dir, "dnsmasq.conf")
  end

  def to_config(
        %__MODULE__{
          interface: interface,
          listen_address: listen_address,
          server: server,
          dhcp_range_min: dhcp_range_min,
          dhcp_range_max: dhcp_range_max,
          lease_time_hours: lease_time
        } = dnsmasq
      ) do
    contents = """
    interface=#{interface}
    listen-address=#{listen_address}
    server=#{server}
    dhcp-range=#{dhcp_range_min},#{dhcp_range_max},#{lease_time}
    """

    bool_opts = get_active_opts(dnsmasq)

    Enum.reduce(bool_opts, String.trim(contents), fn active_opt, config ->
      config <> "\n#{active_opt}"
    end)
  end

  @spec write_config_file(t()) :: :ok | {:error, File.posix()}
  def write_config_file(dnsmasq) do
    config_contents = to_config(dnsmasq)
    :ok = NetworkNG.ensure_tmp_dir()

    config_file_path()
    |> File.write(config_contents)
  end

  def get_active_opts(dnsmasq) do
    dnsmasq
    |> Map.from_struct()
    |> Enum.filter(&opt_active?/1)
    |> Enum.map(fn {optname, _} -> opt_name_to_string(optname) end)
  end

  def run() do
    NetworkNG.run_cmd("dnsmasq", ["-C", config_file_path()])
  end

  defp opt_active?({_, true}), do: true
  defp opt_active?({_, _}), do: false

  defp opt_name_to_string(:bind_interfaces), do: "bind-interfaces"
  defp opt_name_to_string(:domain_needed), do: "domain-needed"
  defp opt_name_to_string(:bogus_priv), do: "bogus-priv"
end
