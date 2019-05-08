defmodule VintageNet.Technology.WiFi do
  @behaviour VintageNet.Technology

  alias VintageNet.WiFi.{Scan, WPA2}
  alias VintageNet.Interface.RawConfig

  @impl true
  def to_raw_config(ifname, %{type: __MODULE__, wifi: wifi_config} = config, opts) do
    ifup = Keyword.fetch!(opts, :bin_ifup)
    ifdown = Keyword.fetch!(opts, :bin_ifdown)
    wpa_supplicant = Keyword.fetch!(opts, :bin_wpa_supplicant)
    killall = Keyword.fetch!(opts, :bin_killall)
    tmpdir = Keyword.fetch!(opts, :tmpdir)

    network_interfaces_path = Path.join(tmpdir, "network_interfaces.#{ifname}")
    wpa_supplicant_conf_path = Path.join(tmpdir, "wpa_supplicant.conf.#{ifname}")
    control_interface_path = Path.join(tmpdir, "wpa_supplicant")

    hostname = config[:hostname] || get_hostname()

    files = [
      {network_interfaces_path, "iface #{ifname} inet dhcp" <> dhcp_options(hostname)},
      {wpa_supplicant_conf_path, wifi_to_supplicant_contents(wifi_config, control_interface_path)}
    ]

    up_cmds = [
      {:run, wpa_supplicant, ["-B", "-i", ifname, "-c", wpa_supplicant_conf_path, "-dd"]},
      {:run, ifup, ["-i", network_interfaces_path, ifname]}
    ]

    down_cmds = [
      {:run, ifdown, ["-i", network_interfaces_path, ifname]},
      {:run, killall, ["-q", "wpa_supplicant"]}
    ]

    {:ok,
     %RawConfig{
       ifname: ifname,
       type: __MODULE__,
       source_config: config,
       files: files,
       child_specs: [{VintageNet.Interface.ConnectivityChecker, ifname}],
       up_cmds: up_cmds,
       down_cmds: down_cmds
     }}
  end

  def to_raw_config(ifname, %{type: __MODULE__}, opts) do
    wpa_supplicant = Keyword.fetch!(opts, :bin_wpa_supplicant)
    killall = Keyword.fetch!(opts, :bin_killall)
    tmpdir = Keyword.fetch!(opts, :tmpdir)
    wpa_supplicant_conf_path = Path.join(tmpdir, "wpa_supplicant.conf.#{ifname}")
    control_interface_path = Path.join(tmpdir, "wpa_supplicant")

    files = [
      {wpa_supplicant_conf_path, "ctrl_interface=#{control_interface_path}"}
    ]

    up_cmds = [
      {:run, wpa_supplicant, ["-B", "-i", ifname, "-c", wpa_supplicant_conf_path, "-dd"]}
    ]

    down_cmds = [
      {:run, killall, ["-q", "wpa_supplicant"]}
    ]

    {:ok,
     %RawConfig{
       ifname: ifname,
       type: __MODULE__,
       files: files,
       child_specs: [{VintageNet.Interface.ConnectivityChecker, ifname}],
       up_cmds: up_cmds,
       down_cmds: down_cmds
     }}
  end

  def to_raw_config(_ifname, _config, _opts) do
    {:error, :bad_configuration}
  end

  @impl true
  def ioctl(ifname, :scan, _args) do
    Scan.scan(ifname)
  end

  def ioctl(_ifname, _command, _args) do
    {:error, :unsupported}
  end

  defp wifi_to_supplicant_contents(wifi, control_interface_path) do
    """
    ctrl_interface=#{control_interface_path}
    country=#{wifi.regulatory_domain}
    """ <> into_wifi_network_config(wifi)
  end

  defp key_mgmt_to_string(key) when key in [:none, :wep], do: "NONE"
  defp key_mgmt_to_string(:wpa_psk), do: "WPA-PSK"

  defp into_wifi_network_config(%{networks: networks}) do
    Enum.reduce(networks, "", fn network, config ->
      config <> into_wifi_network_config(network)
    end)
  end

  defp into_wifi_network_config(%{key_mgmt: :wep} = wifi) do
    """
    network={
    #{into_config_string(wifi, :ssid)}
    key_mgmt=NONE
    wep_tx_keyidx=0
    wep_key0=#{wifi.psk}
    }
    """
  end

  defp into_wifi_network_config(wifi) do
    """
    network={
    #{into_config_string(wifi, :ssid)}
    #{into_config_string(wifi, :psk)}
    #{into_config_string(wifi, :key_mgmt)}
    #{into_config_string(wifi, :scan_ssid)}
    #{into_config_string(wifi, :priority)}
    }
    """
  end

  defp into_config_string(wifi, opt_key) do
    case Map.get(wifi, opt_key) do
      nil -> ""
      opt -> wifi_opt_to_config_string(wifi, opt_key, opt)
    end
  end

  defp wifi_opt_to_config_string(_wifi, :ssid, ssid) do
    "ssid=#{inspect(ssid)}"
  end

  defp wifi_opt_to_config_string(wifi, :psk, psk) do
    {:ok, real_psk} = WPA2.to_psk(wifi.ssid, psk)
    "psk=#{real_psk}"
  end

  defp wifi_opt_to_config_string(_wifi, :key_mgmt, key_mgmt) do
    "key_mgmt=#{key_mgmt_to_string(key_mgmt)}"
  end

  defp wifi_opt_to_config_string(_wifi, :scan_ssid, value) do
    "scan_ssid=#{value}"
  end

  defp wifi_opt_to_config_string(_wifi, :priority, value) do
    "priority=#{value}"
  end

  # TODO: Remove duplication with ethernet!!
  defp dhcp_options(hostname) do
    """

      script #{udhcpc_handler_path()}
      hostname #{hostname}
    """
  end

  defp udhcpc_handler_path() do
    Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])
  end

  defp get_hostname do
    {:ok, hostname} = :inet.gethostname()
    to_string(hostname)
  end
end
