defmodule Nerves.NetworkNG.HostAPD do
  alias Nerves.NetworkNG

  defstruct interface: nil,
            driver: :nl80211,
            ssid: nil,
            hw_mode: "g",
            channel: 6,
            ieee80211n: 1,
            wmm_enabled: 1,
            ht_capab: "[HT40][SHORT-GI-20][DSSS_CCk-40]",
            macaddr_acl: 0,
            auth_algs: 1,
            ignore_broadcast_ssid: 0,
            wpa: 2,
            wpa_key_mgmt: "WPA-PSK",
            wpa_passphrase: nil,
            rsn_pairwise: "CCMP"

  def new(interface, ssid, psk, opts \\ []) do
    opts = [interface: interface, ssid: ssid, wpa_passphrase: psk] |> Keyword.merge(opts)
    struct(__MODULE__, opts)
  end

  def config_file_path() do
    Path.join(NetworkNG.tmp_dir(), "hostapd.conf")
  end

  def to_config(hostapd) do
    config = Map.from_struct(hostapd)

    Enum.reduce(config, "", fn {config_name, config_value}, contents ->
      contents <> "#{config_name}=#{config_value}\n"
    end)
  end

  def run() do
    NetworkNG.run_cmd("hostapd", [config_file_path(), "-B"])
  end

  def write_config_file(hostapd) do
    contents = to_config(hostapd)
    :ok = NetworkNG.ensure_tmp_dir()

    config_file_path()
    |> File.write(contents)
  end
end
