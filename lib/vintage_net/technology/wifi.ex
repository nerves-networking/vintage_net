defmodule VintageNet.Technology.WiFi do
  @behaviour VintageNet.Technology

  alias VintageNet.WiFi.{WPA2, WPASupplicant}
  alias VintageNet.Interface.RawConfig
  alias VintageNet.IP.{ConfigToInterfaces, ConfigToUdhcpd}

  @impl true
  def normalize(%{type: __MODULE__, wifi: %{ssid: ssid, psk: psk}} = config) do
    # If the user passes in a passphrase for the PSK, change it to a PSK
    {:ok, real_psk} = WPA2.to_psk(ssid, psk)
    {:ok, put_in(config.wifi.psk, real_psk)}
  end

  def normalize(%{type: __MODULE__, wifi: %{networks: networks}} = config) do
    # If the user passes in a passphrase for the PSK, change it to a PSK
    networks =
      Enum.map(networks, fn
        %{ssid: ssid, psk: psk} = network ->
          {:ok, real_psk} = WPA2.to_psk(ssid, psk)
          %{network | psk: real_psk}

        network ->
          network
      end)

    {:ok, put_in(config.wifi.networks, networks)}
  end

  def normalize(%{type: __MODULE__} = config), do: {:ok, config}

  @impl true
  def to_raw_config(ifname, %{type: __MODULE__, wifi: %{}} = config, opts) do
    ifup = Keyword.fetch!(opts, :bin_ifup)
    ifdown = Keyword.fetch!(opts, :bin_ifdown)
    wpa_supplicant = Keyword.fetch!(opts, :bin_wpa_supplicant)
    tmpdir = Keyword.fetch!(opts, :tmpdir)
    regulatory_domain = Keyword.fetch!(opts, :regulatory_domain)

    network_interfaces_path = Path.join(tmpdir, "network_interfaces.#{ifname}")
    wpa_supplicant_conf_path = Path.join(tmpdir, "wpa_supplicant.conf.#{ifname}")
    control_interface_dir = Path.join(tmpdir, "wpa_supplicant")
    control_interface_paths = ctrl_interface_paths(ifname, control_interface_dir, config)
    ap_mode = ap_mode?(config)

    {:ok, normalized_config} = normalize(config)

    files = [
      {network_interfaces_path,
       ConfigToInterfaces.config_to_interfaces_contents(ifname, normalized_config)},
      {wpa_supplicant_conf_path,
       wifi_to_supplicant_contents(
         normalized_config.wifi,
         control_interface_dir,
         regulatory_domain
       )}
    ]

    up_cmds = [
      {:run_ignore_errors, ifdown, ["-i", network_interfaces_path, ifname]},
      {:run, ifup, ["-i", network_interfaces_path, ifname]}
    ]

    down_cmds = [
      {:run, ifdown, ["-i", network_interfaces_path, ifname]}
    ]

    case maybe_add_udhcpd(ifname, normalized_config, opts) do
      {udhcpd_files, udhcpd_up_cmds, udhcpd_down_cmds} ->
        {:ok,
         %RawConfig{
           ifname: ifname,
           type: __MODULE__,
           source_config: normalized_config,
           files: files ++ udhcpd_files,
           cleanup_files: control_interface_paths,
           child_specs: [
             {VintageNet.Interface.LANConnectivityChecker, ifname},
             {WPASupplicant,
              wpa_supplicant: wpa_supplicant,
              ifname: ifname,
              wpa_supplicant_conf_path: wpa_supplicant_conf_path,
              control_path: control_interface_dir,
              ap_mode: ap_mode}
           ],
           up_cmds: up_cmds ++ udhcpd_up_cmds,
           up_cmd_millis: 60_000,
           down_cmds: down_cmds ++ udhcpd_down_cmds
         }}

      nil ->
        {:ok,
         %RawConfig{
           ifname: ifname,
           type: __MODULE__,
           source_config: normalized_config,
           files: files,
           cleanup_files: control_interface_paths,
           child_specs: [
             {VintageNet.Interface.InternetConnectivityChecker, ifname},
             {WPASupplicant,
              wpa_supplicant: wpa_supplicant,
              ifname: ifname,
              wpa_supplicant_conf_path: wpa_supplicant_conf_path,
              control_path: control_interface_dir,
              ap_mode: ap_mode}
           ],
           up_cmds: up_cmds,
           up_cmd_millis: 60_000,
           down_cmds: down_cmds
         }}
    end
  end

  def to_raw_config(ifname, %{type: __MODULE__} = config, opts) do
    wpa_supplicant = Keyword.fetch!(opts, :bin_wpa_supplicant)
    tmpdir = Keyword.fetch!(opts, :tmpdir)

    wpa_supplicant_conf_path = Path.join(tmpdir, "wpa_supplicant.conf.#{ifname}")
    control_interface_dir = Path.join(tmpdir, "wpa_supplicant")
    control_interface_paths = ctrl_interface_paths(ifname, control_interface_dir, config)

    files = [
      {wpa_supplicant_conf_path, "ctrl_interface=#{control_interface_dir}"}
    ]

    {:ok,
     %RawConfig{
       ifname: ifname,
       type: __MODULE__,
       source_config: %{type: __MODULE__},
       files: files,
       child_specs: [
         {VintageNet.Interface.InternetConnectivityChecker, ifname},
         {WPASupplicant,
          wpa_supplicant: wpa_supplicant,
          ifname: ifname,
          wpa_supplicant_conf_path: wpa_supplicant_conf_path,
          control_path: control_interface_dir,
          ap_mode: false}
       ],
       cleanup_files: control_interface_paths
     }}
  end

  def to_raw_config(_ifname, _config, _opts) do
    {:error, :bad_configuration}
  end

  defp maybe_add_udhcpd(ifname, %{dhcpd: _dhcpd} = config, opts) do
    tmpdir = Keyword.fetch!(opts, :tmpdir)
    killall = Keyword.fetch!(opts, :bin_killall)
    udhcpd = Keyword.fetch!(opts, :bin_udhcpd)
    udhcpd_conf_path = Path.join(tmpdir, "udhcpd.conf.#{ifname}")

    files = [
      {udhcpd_conf_path, ConfigToUdhcpd.config_to_udhcpd_contents(ifname, config, tmpdir)}
    ]

    up_cmds = [
      {:run, udhcpd, [udhcpd_conf_path]}
    ]

    down_cmds = [
      {:run, killall, ["-q", "udhcpd"]}
    ]

    {files, up_cmds, down_cmds}
  end

  defp maybe_add_udhcpd(_, _, _), do: nil

  @impl true
  def ioctl(ifname, :scan, _args) do
    WPASupplicant.scan(ifname)
  end

  def ioctl(_ifname, _command, _args) do
    {:error, :unsupported}
  end

  @impl true
  def check_system(_opts) do
    # TODO
    :ok
  end

  defp wifi_to_supplicant_contents(wifi, control_interface_dir, regulatory_domain) do
    config = [
      "ctrl_interface=#{control_interface_dir}",
      "country=#{wifi[:regulatory_domain] || regulatory_domain}",
      into_config_string(wifi, :bgscan),
      into_config_string(wifi, :ap_scan)
    ]

    iodata = into_newlines(config) ++ into_wifi_network_config(wifi)
    IO.iodata_to_binary(iodata)
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

  defp bgscan_to_string(:simple), do: "\"simple\""
  defp bgscan_to_string({:simple, args}), do: "\"simple:#{args}\""
  defp bgscan_to_string(:learn), do: "\"learn\""
  defp bgscan_to_string({:learn, args}), do: "\"learn:#{args}\""

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

  defp wifi_opt_to_config_string(_wifi, :psk, psk) do
    "psk=#{psk}"
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

  defp wifi_opt_to_config_string(_wifi, :ap_scan, value) do
    "ap_scan=#{value}"
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

  defp wifi_opt_to_config_string(_wifi, :bgscan, value) do
    "bgscan=#{bgscan_to_string(value)}"
  end

  defp wifi_opt_to_config_string(_wifi, :passive_scan, value) do
    "passive_scan=#{value}"
  end

  defp network_config(config) do
    ["network={", "\n", into_newlines(config), "}", "\n"]
  end

  defp into_newlines(config) do
    Enum.map(config, fn
      nil -> []
      conf -> [conf, "\n"]
    end)
  end

  defp ap_mode?(%{wifi: %{mode: mode}}) when mode in [:host, 2], do: true
  defp ap_mode?(_config), do: false

  defp ctrl_interface_paths(ifname, dir, %{wifi: %{mode: mode}}) when mode in [:host, 2] do
    # Some WiFi drivers expose P2P interfaces and those should be cleaned up too.
    [Path.join(dir, "p2p-dev-#{ifname}"), Path.join(dir, ifname)]
  end

  defp ctrl_interface_paths(ifname, dir, _),
    do: [Path.join(dir, ifname)]
end
