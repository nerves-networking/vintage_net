defmodule VintageNet.Technology.WiFi do
  @behaviour VintageNet.Technology

  alias VintageNet.WiFi.{Scan, WPA2}
  alias VintageNet.Interface.RawConfig
  alias VintageNet.IP.ConfigToInterfaces

  @impl true
  def to_raw_config(ifname, %{type: __MODULE__, wifi: wifi_config} = config, opts) do
    ifup = Keyword.fetch!(opts, :bin_ifup)
    ifdown = Keyword.fetch!(opts, :bin_ifdown)
    wpa_supplicant = Keyword.fetch!(opts, :bin_wpa_supplicant)
    killall = Keyword.fetch!(opts, :bin_killall)
    tmpdir = Keyword.fetch!(opts, :tmpdir)
    regulatory_domain = Keyword.fetch!(opts, :regulatory_domain)

    network_interfaces_path = Path.join(tmpdir, "network_interfaces.#{ifname}")
    wpa_supplicant_conf_path = Path.join(tmpdir, "wpa_supplicant.conf.#{ifname}")
    control_interface_path = Path.join(tmpdir, "wpa_supplicant")

    files = [
      {network_interfaces_path, ConfigToInterfaces.config_to_interfaces_contents(ifname, config)},
      {wpa_supplicant_conf_path,
       wifi_to_supplicant_contents(wifi_config, control_interface_path, regulatory_domain)}
    ]

    up_cmds = [
      {:run_ignore_errors, killall, ["-q", "wpa_supplicant"]},
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
       cleanup_files: [Path.join(control_interface_path, ifname)],
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
       down_cmds: down_cmds,
       cleanup_files: [Path.join(control_interface_path, ifname)]
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

  @impl true
  def check_system(_opts) do
    # TODO
    :ok
  end

  defp wifi_to_supplicant_contents(wifi, control_interface_path, regulatory_domain) do
    [
      "ctrl_interface=#{control_interface_path}",
      "\n",
      "country=#{regulatory_domain}",
      "\n",
      into_wifi_network_config(wifi)
    ]
    |> IO.iodata_to_binary()
  end

  defp key_mgmt_to_string(:none), do: "NONE"
  defp key_mgmt_to_string(:wpa_psk), do: "WPA-PSK"
  defp key_mgmt_to_string(:wpa_eap), do: "WPA-EAP"
  defp key_mgmt_to_string(:IEEE8021X), do: "IEEE8021X"
  # This is to allow passing multi mgmts
  defp key_mgmt_to_string(string) when is_binary(string), do: string

  defp mode_to_string(:client), do: "0"
  defp mode_to_string(:adhoc), do: "1"
  defp mode_to_string(:host), do: "2"
  # In case the user supplies data as the integer type
  defp mode_to_string(mode) when is_integer(mode), do: mode

  defp into_wifi_network_config(%{networks: networks}) do
    Enum.map(networks, &into_wifi_network_config/1)
  end

  defp into_wifi_network_config(wifi) do
    network_config([
      # Common settings
      into_config_string(wifi, :ssid),
      into_config_string(wifi, :bssid),
      into_config_string(wifi, :key_mgmt),
      into_config_string(wifi, :scan_ssid),
      into_config_string(wifi, :priority),
      into_config_string(wifi, :bssid_whitelist),
      into_config_string(wifi, :bssid_blacklist),
      into_config_string(wifi, :wps_disabled),
      into_config_string(wifi, :mode),
      into_config_string(wifi, :ap_scan),

      # WPA-PSK settings
      into_config_string(wifi, :psk),
      into_config_string(wifi, :wpa_ptk_rekey),

      # MACSEC settings
      into_config_string(wifi, :macsec_policy),
      into_config_string(wifi, :macsec_integ_only),
      into_config_string(wifi, :macsec_replay_protect),
      into_config_string(wifi, :macsec_replay_window),
      into_config_string(wifi, :macsec_port),
      into_config_string(wifi, :mka_cak),
      into_config_string(wifi, :mka_ckn),
      into_config_string(wifi, :mka_priority),

      # EAP settings
      into_config_string(wifi, :identity),
      into_config_string(wifi, :anonymous_identity),
      into_config_string(wifi, :password),
      into_config_string(wifi, :pairwise),
      into_config_string(wifi, :group),
      into_config_string(wifi, :group_mgmt),
      into_config_string(wifi, :eap),
      into_config_string(wifi, :eapol_flags),
      into_config_string(wifi, :phase1),
      into_config_string(wifi, :phase2),
      into_config_string(wifi, :fragment_size),
      into_config_string(wifi, :ocsp),
      into_config_string(wifi, :openssl_ciphers),
      into_config_string(wifi, :erp),

      # TODO:
      # These parts are files.
      # They should probably be added to the `files` part
      # of raw_config
      into_config_string(wifi, :ca_cert),
      into_config_string(wifi, :ca_cert2),
      into_config_string(wifi, :dh_file),
      into_config_string(wifi, :dh_file2),
      into_config_string(wifi, :client_cert),
      into_config_string(wifi, :client_cert2),
      into_config_string(wifi, :private_key),
      into_config_string(wifi, :private_key2),
      into_config_string(wifi, :private_key_passwd),
      into_config_string(wifi, :private_key2_passwd),
      into_config_string(wifi, :pac_file),

      # WEP Settings
      into_config_string(wifi, :auth_alg),
      into_config_string(wifi, :wep_key0),
      into_config_string(wifi, :wep_key1),
      into_config_string(wifi, :wep_key2),
      into_config_string(wifi, :wep_key3),
      into_config_string(wifi, :wep_tx_keyidx),

      # SIM Settings
      into_config_string(wifi, :pin),
      into_config_string(wifi, :pcsc)
    ])
  end

  defp into_config_string(wifi, opt_key) do
    case Map.get(wifi, opt_key) do
      nil -> nil
      opt -> wifi_opt_to_config_string(wifi, opt_key, opt)
    end
  end

  defp wifi_opt_to_config_string(_wifi, :ssid, ssid) do
    "ssid=#{inspect(ssid)}"
  end

  defp wifi_opt_to_config_string(_wifi, :bssid, bssid) do
    "bssid=#{bssid}"
  end

  defp wifi_opt_to_config_string(wifi, :psk, psk) do
    {:ok, real_psk} = WPA2.to_psk(wifi.ssid, psk)
    "psk=#{real_psk}"
  end

  defp wifi_opt_to_config_string(_wifi, :wpa_ptk_rekey, wpa_ptk_rekey) do
    "wpa_ptk_rekey=#{wpa_ptk_rekey}"
  end

  defp wifi_opt_to_config_string(_wifi, :key_mgmt, key_mgmt) do
    "key_mgmt=#{key_mgmt_to_string(key_mgmt)}"
  end

  defp wifi_opt_to_config_string(_wifi, :mode, mode) do
    "mode=#{mode_to_string(mode)}"
  end

  defp wifi_opt_to_config_string(_wifi, :scan_ssid, value) do
    "scan_ssid=#{value}"
  end

  defp wifi_opt_to_config_string(_wifi, :priority, value) do
    "priority=#{value}"
  end

  defp wifi_opt_to_config_string(_wifi, :identity, value) do
    "identity=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :anonymous_identity, value) do
    "anonymous_identity=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :password, value) do
    "password=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :phase1, value) do
    "phase1=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :phase2, value) do
    "phase2=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :pairwise, value) do
    "pairwise=#{value}"
  end

  defp wifi_opt_to_config_string(_wifi, :group, value) do
    "group=#{value}"
  end

  defp wifi_opt_to_config_string(_wifi, :eap, value) do
    "eap=#{value}"
  end

  defp wifi_opt_to_config_string(_wifi, :eapol_flags, value) do
    "eapol_flags=#{value}"
  end

  defp wifi_opt_to_config_string(_wifi, :ca_cert, value) do
    "ca_cert=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :ca_cert2, value) do
    "ca_cert2=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :client_cert, value) do
    "client_cert=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :client_cert2, value) do
    "client_cert2=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :private_key, value) do
    "private_key=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :private_key2, value) do
    "private_key2=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :private_key_passwd, value) do
    "private_key_passwd=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :private_key2_passwd, value) do
    "private_key2_passwd=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :pin, value) do
    "pin=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :wep_tx_keyidx, value) do
    "wep_tx_keyidx=#{value}"
  end

  defp wifi_opt_to_config_string(_wifi, :wep_key0, value) do
    "wep_key0=#{value}"
  end

  defp wifi_opt_to_config_string(_wifi, :wep_key1, value) do
    "wep_key1=#{value}"
  end

  defp wifi_opt_to_config_string(_wifi, :wep_key2, value) do
    "wep_key2=#{value}"
  end

  defp wifi_opt_to_config_string(_wifi, :wep_key3, value) do
    "wep_key3=#{value}"
  end

  defp wifi_opt_to_config_string(_wifi, :pcsc, value) do
    "pcsc=#{inspect(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :bssid_blacklist, value) do
    "bssid_blacklist=#{value}"
  end

  defp wifi_opt_to_config_string(_wifi, :bssid_whitelist, value) do
    "bssid_whitelist=#{value}"
  end

  defp network_config(config) do
    config =
      Enum.map(config, fn
        nil -> []
        conf -> [conf, "\n"]
      end)

    ["network={", "\n", config, "}", "\n"]
  end
end
