defmodule VintageNet.Technology.WiFi do
  @behaviour VintageNet.Technology

  require Logger

  alias VintageNet.WiFi.{WPA2, WPASupplicant}
  alias VintageNet.Interface.RawConfig
  alias VintageNet.IP.{IPv4Config, DhcpdConfig}

  # These configuration keys are common to all network specifications
  # and allowed to pass through network normalization.
  @common_network_keys [
    :mode,
    :key_mgmt,
    :ssid,
    :bssid,
    :bssid_whitelist,
    :bssid_blacklist,
    :priority,
    :scan_ssid
  ]

  @moduledoc """
  Support for common Wi-Fi interface configurations

  Configurations for this technology are maps with a `:type` field set
  to `VintageNet.Technology.WiFi`. The following additional fields
  are supported:

  * `:wifi` - WiFi options
  * `:ipv4` - IPv4 options. See VintageNet.IP.IPv4Config.

  To scan for WiFi networks it's sufficient to pass an empty configuration:

  ```elixir
  %{type: VintageNet.Technology.WiFi}
  ```

  Here's a typical configuration for connecting to a WPA2-protected Wi-Fi network:

  ```elixir
  %{
    type: VintageNet.Technology.WiFi,
    wifi: %{
      mode: :client,
      networks: [%{ssid: "my_network_ssid", key_mgmt: :wpa_psk, psk: "a_passphrase_or_psk"}]
    },
    ipv4: %{method: :dhcp}
  }
  ```

  If your Wi-Fi adapter or module has support for running as an Access Point,
  then the following configuration puts it in AP mode, assigns a static IP
  address of 192.168.0.1 and gives clients IP addresses from 192.168.0.30
  to 192.168.0.254.

  ```elixir
  %{
    type: VintageNet.Technology.WiFi,
    wifi: %{
      mode: :host,
      networks: [
        %{
          ssid: "test ssid",
          key_mgmt: :none
        }
      ]
    },
    ipv4: %{
      method: :static,
      address: {192, 168, 0, 1},
      prefix_length: 24
    },
    dhcpd: %{
      start: {192, 168, 0, 30},
      end: {192, 168, 0, 254}
    }
  }
  ```
  """

  @impl true
  def normalize(%{type: __MODULE__} = config) do
    config
    |> normalize_wifi()
    |> IPv4Config.normalize()
    |> DhcpdConfig.normalize()
  end

  defp normalize_wifi(%{wifi: wifi} = config) do
    new_wifi =
      wifi
      |> normalize_first_network()
      |> normalize_networks()
      |> Map.take([:ap_scan, :networks, :bgscan, :passive_scan, :regulatory_domain])

    %{config | wifi: new_wifi}
  end

  defp normalize_wifi(_config) do
    # If wifi isn't configured, then only scanning is allowed.
    %{type: __MODULE__, wifi: %{networks: []}, ipv4: %{method: :disabled}}
  end

  defp normalize_first_network(%{ssid: ssid} = wifi) do
    # If user specified a standalone ssid, move it to the first spot
    # in the networks list so that networks are only stored in one place.

    _ =
      Logger.warn(
        "Passing Wi-Fi network parameters outside of `:networks` for ssid '#{ssid}' is deprecated. See `VintageNet.info` for the fixed configuration."
      )

    # Rather than figure out which keys are relevant, move them all to
    # the first place in networks and let the network normalization code
    # figure it out.
    first_network = Map.drop(wifi, [:networks])

    Map.update(wifi, :networks, [first_network], &[first_network | &1])
  end

  defp normalize_first_network(wifi), do: wifi

  defp normalize_networks(%{networks: networks} = wifi) do
    # Normalize the networks and remove any dupes
    new_networks =
      networks
      |> Enum.map(fn network -> network |> normalize_network() |> normalize_network_mode() end)
      |> Enum.uniq()

    %{wifi | networks: new_networks}
  end

  defp normalize_networks(wifi) do
    # No networks specified so add an empty list
    Map.put(wifi, :networks, [])
  end

  defp normalize_network_mode(%{mode: mode} = network_config) when mode in [:host, :client] do
    network_config
  end

  defp normalize_network_mode(%{mode: other_mode}) do
    raise ArgumentError, "invalid wifi mode #{inspect(other_mode)}. Specify :host or :client"
  end

  defp normalize_network_mode(network_config), do: Map.put(network_config, :mode, :client)

  # WEP
  defp normalize_network(
         %{
           key_mgmt: :none,
           ssid: _ssid,
           wep_tx_keyidx: _wep_tx_keyidx
         } = network_config
       ) do
    Map.take(
      network_config,
      [:wep_key0, :wep_key1, :wep_key2, :wep_key3, :wep_tx_keyidx | @common_network_keys]
    )
  end

  # No Security
  defp normalize_network(%{key_mgmt: :none} = network_config) do
    Map.take(network_config, @common_network_keys)
  end

  # WPA-PSK
  defp normalize_network(%{key_mgmt: :wpa_psk, ssid: ssid, psk: psk} = network_config) do
    case WPA2.to_psk(ssid, psk) do
      {:ok, real_psk} ->
        network_config
        |> Map.take([:wpa_ptk_rekey, :pairwise | @common_network_keys])
        |> Map.put(:psk, real_psk)

      {:error, :invalid_characters} ->
        raise ArgumentError, "Invalid characters in SSID #{inspect(ssid)} or its password"

      {:error, :password_too_long} ->
        raise ArgumentError, "Passphrase for SSID #{inspect(ssid)} is too long"

      {:error, :ssid_too_long} ->
        raise ArgumentError, "SSID #{inspect(ssid)} is too long"
    end
  end

  # WPA-EAP or IEEE8021X (TODO)
  defp normalize_network(%{key_mgmt: key_mgmt, ssid: _ssid} = network_config)
       when key_mgmt in [:wpa_eap, :IEEE8021X] do
    Map.take(network_config, [
      :anonymous_identity,
      :ca_cert,
      :ca_cert2,
      :client_cert,
      :client_cert2,
      :eap,
      :eapol_flags,
      :group,
      :identity,
      :pairwise,
      :password,
      :pcsc,
      :phase1,
      :phase2,
      :pin,
      :private_key,
      :private_key_passwd,
      :private_key2,
      :private_key2_passwd
      | @common_network_keys
    ])
  end

  defp normalize_network(%{ssid: _ssid} = network) do
    # Default to no security and try again.
    network
    |> Map.put(:key_mgmt, :none)
    |> normalize_network()
  end

  defp normalize_network(network) do
    raise ArgumentError, "don't know how to process #{inspect(network)}"
  end

  @impl true
  def to_raw_config(ifname, %{type: __MODULE__} = config, opts) do
    wpa_supplicant = Keyword.fetch!(opts, :bin_wpa_supplicant)
    tmpdir = Keyword.fetch!(opts, :tmpdir)
    regulatory_domain = Keyword.fetch!(opts, :regulatory_domain)

    wpa_supplicant_conf_path = Path.join(tmpdir, "wpa_supplicant.conf.#{ifname}")
    control_interface_dir = Path.join(tmpdir, "wpa_supplicant")
    control_interface_paths = ctrl_interface_paths(ifname, control_interface_dir, config)
    ap_mode = ap_mode?(config)

    normalized_config = normalize(config)

    files = [
      {wpa_supplicant_conf_path,
       wifi_to_supplicant_contents(
         normalized_config.wifi,
         control_interface_dir,
         regulatory_domain
       )}
    ]

    %RawConfig{
      ifname: ifname,
      type: __MODULE__,
      source_config: normalized_config,
      files: files,
      cleanup_files: control_interface_paths,
      restart_strategy: :rest_for_one,
      child_specs: [
        {WPASupplicant,
         wpa_supplicant: wpa_supplicant,
         ifname: ifname,
         wpa_supplicant_conf_path: wpa_supplicant_conf_path,
         control_path: control_interface_dir,
         ap_mode: ap_mode}
      ]
    }
    |> IPv4Config.add_config(normalized_config, opts)
    |> DhcpdConfig.add_config(normalized_config, opts)
  end

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

    iodata = [into_newlines(config), into_wifi_network_config(wifi)]
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

  defp ap_mode?(%{wifi: %{networks: [%{mode: mode}]}}) when mode in [:host, 2], do: true
  defp ap_mode?(_config), do: false

  defp ctrl_interface_paths(ifname, dir, %{wifi: %{networks: [%{mode: mode}]}})
       when mode in [:host, 2] do
    # Some WiFi drivers expose P2P interfaces and those should be cleaned up too.
    [Path.join(dir, "p2p-dev-#{ifname}"), Path.join(dir, ifname)]
  end

  defp ctrl_interface_paths(ifname, dir, _),
    do: [Path.join(dir, ifname)]
end
