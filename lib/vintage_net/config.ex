defmodule VintageNet.Config do
  @doc """
  Builds a vintage network configuration
  """
  def make(networks, opts \\ []) do
    Enum.map(networks, &do_make(&1, opts))
  end

  def get_option(opts, option) do
    case Keyword.fetch(opts, option) do
      :error -> {:error, :option_not_found, option}
      {:ok, _} = result -> result
    end
  end

  defp do_make({ifname, %{type: :mobile, pppd: pppd_config}}, opts) do
    with {:ok, mknod} <- get_option(opts, :mknod),
         {:ok, killall} <- get_option(opts, :killall),
         {:ok, chat_bin} <- get_option(opts, :chat_bin),
         {:ok, pppd} <- get_option(opts, :pppd) do
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
  end

  defp do_make({ifname, %{type: :wifi, wifi: wifi_config}}, opts) do
    with {:ok, ifup} <- get_option(opts, :ifup),
         {:ok, ifdown} <- get_option(opts, :ifdown),
         {:ok, wpa_supplicant} <- get_option(opts, :wpa_supplicant),
         {:ok, killall} <- get_option(opts, :killall) do
      files = [
        {"/tmp/network_interfaces.#{ifname}", "iface #{ifname} inet dhcp"},
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
  end

  defp do_make({ifname, %{type: :ethernet} = _config}, opts) do
    with {:ok, ifup} <- get_option(opts, :ifup),
         {:ok, ifdown} <- get_option(opts, :ifdown) do
      result = %{
        files: [{"/tmp/network_interfaces.#{ifname}", "iface #{ifname} inet dhcp"}],
        up_cmds: [{:run, ifup, ["-i", "/tmp/network_interfaces.#{ifname}", ifname]}],
        down_cmds: [{:run, ifdown, ["-i", "/tmp/network_interfaces.#{ifname}", ifname]}]
      }

      {ifname, result}
    end
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
    ctrl_interface=/tmp/foo
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
end
