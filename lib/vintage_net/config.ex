defmodule VintageNet.Config do
  @doc """
  Builds a vintage network configuration
  """
  def make(networks, opts \\ []) do
    merged_opts = Application.get_all_env(:vintage_net) |> Keyword.merge(opts)
    Enum.map(networks, &do_make(&1, merged_opts))
  end

  defp do_make({ifname, %{type: :mobile, pppd: pppd_config}}, opts) do
    mknod = Keyword.fetch!(opts, :bin_mknod)
    killall = Keyword.fetch!(opts, :bin_killall)
    chat_bin = Keyword.fetch!(opts, :bin_chat)
    pppd = Keyword.fetch!(opts, :bin_pppd)

    files = [{"/tmp/chat_script", pppd_config.chat_script}]

    up_cmds = [
      {:run, mknod, ["/dev/ppp", "c", "108", "0"]},
      {:run, pppd, make_pppd_args(pppd_config, chat_bin)}
    ]

    down_cmds = [
      {:run, killall, ["-q", "pppd"]}
    ]

    {ifname, %{files: files, up_cmds: up_cmds, down_cmds: down_cmds}}
  end

  defp do_make({ifname, %{type: :wifi, wifi: wifi_config}}, opts) do
    ifup = Keyword.fetch!(opts, :bin_ifup)
    ifdown = Keyword.fetch!(opts, :bin_ifdown)
    wpa_supplicant = Keyword.fetch!(opts, :bin_wpa_supplicant)
    killall = Keyword.fetch!(opts, :bin_killall)

    files = [
      {"/tmp/network_interfaces.#{ifname}", "iface #{ifname} inet dhcp" <> dhcp_options()},
      {"/tmp/wpa_supplicant.conf.#{ifname}", wifi_to_supplicant_contents(wifi_config)}
    ]

    up_cmds = [
      {:run, wpa_supplicant,
       ["-B", "-i", ifname, "-c", "/tmp/wpa_supplicant.conf.#{ifname}", "-dd"]},
      {:run, ifup, ["-i", "/tmp/network_interfaces.#{ifname}", ifname]}
    ]

    down_cmds = [
      {:run, ifdown, ["-i", "/tmp/network_interfaces.#{ifname}", ifname]},
      {:run, killall, ["-q", "wpa_supplicant"]}
    ]

    {ifname, %{files: files, up_cmds: up_cmds, down_cmds: down_cmds}}
  end

  defp do_make({ifname, %{type: :wifi}}, opts) do
    wpa_supplicant = Keyword.fetch!(opts, :bin_wpa_supplicant)
    killall = Keyword.fetch!(opts, :bin_killall)

    files = [
      {"/tmp/wpa_supplicant.conf.#{ifname}", "ctrl_interface=/tmp/wpa_supplicant"}
    ]

    up_cmds = [
      {:run, wpa_supplicant,
       ["-B", "-i", ifname, "-c", "/tmp/wpa_supplicant.conf.#{ifname}", "-dd"]}
    ]

    down_cmds = [
      {:run, killall, ["-q", "wpa_supplicant"]}
    ]

    {ifname, %{files: files, up_cmds: up_cmds, down_cmds: down_cmds}}
  end

  defp do_make({ifname, %{type: :ethernet} = _config}, opts) do
    ifup = Keyword.fetch!(opts, :bin_ifup)
    ifdown = Keyword.fetch!(opts, :bin_ifdown)

    result = %{
      files: [
        {"/tmp/network_interfaces.#{ifname}", "iface #{ifname} inet dhcp" <> dhcp_options()}
      ],
      up_cmds: [{:run, ifup, ["-i", "/tmp/network_interfaces.#{ifname}", ifname]}],
      down_cmds: [{:run, ifdown, ["-i", "/tmp/network_interfaces.#{ifname}", ifname]}]
    }

    {ifname, result}
  end

  defp make_pppd_args(pppd, chat_bin) do
    [
      "connect",
      "#{chat_bin} -v -f /tmp/chat_script",
      pppd.ttyname,
      "#{pppd.speed}"
    ] ++ Enum.map(pppd.options, &pppd_option_to_string/1)
  end

  defp pppd_option_to_string(:noipdefault), do: "noipdefault"
  defp pppd_option_to_string(:usepeerdns), do: "usepeerdns"
  defp pppd_option_to_string(:defaultroute), do: "defaultroute"
  defp pppd_option_to_string(:persist), do: "persist"
  defp pppd_option_to_string(:noauth), do: "noauth"

  defp wifi_to_supplicant_contents(wifi) do
    """
    ctrl_interface=/tmp/wpa_supplicant
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
      opt -> wifi_opt_to_config_string(opt_key, opt)
    end
  end

  defp wifi_opt_to_config_string(:ssid, ssid) do
    "ssid=#{inspect(ssid)}"
  end

  defp wifi_opt_to_config_string(:psk, psk) do
    "psk=#{psk}"
  end

  defp wifi_opt_to_config_string(:key_mgmt, key_mgmt) do
    "key_mgmt=#{key_mgmt_to_string(key_mgmt)}"
  end

  defp wifi_opt_to_config_string(:scan_ssid, value) do
    "scan_ssid=#{value}"
  end

  defp wifi_opt_to_config_string(:priority, value) do
    "priority=#{value}"
  end

  defp dhcp_options() do
    """

      script #{udhcpc_handler_path()}
    """
  end

  defp udhcpc_handler_path() do
    Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])
  end
end
