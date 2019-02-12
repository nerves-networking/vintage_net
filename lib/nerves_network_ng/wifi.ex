defmodule Nerves.NetworkNG.WiFi do
  @moduledoc """
  Module for Wifi configuration
  """

  alias Nerves.NetworkNG

  @type address_method :: :dhcp | :static

  @enforce_keys [:ssid, :psk]
  defstruct ctrl_interface: "/var/run/wpa_supplicant",
            ssid: nil,
            psk: nil,
            key_mgmt: "WPA-PSK",
            address_family: :inet,
            address_method: :dhcp,
            iface: "wlan0",
            address: nil,
            netmask: nil,
            network: nil,
            broadcast: nil

  def new(interface, ssid, psk, opts \\ []) do
    opts =
      [ssid: ssid, psk: psk, interface: interface]
      |> Keyword.merge(opts)

    struct(__MODULE__, opts)
  end

  def wpa_file() do
    tmp_dir = NetworkNG.tmp_dir()
    Path.join(tmp_dir, "wpa_supplicant.conf")
  end

  def interfaces_file() do
    tmp_dir = NetworkNG.tmp_dir()
    Path.join(tmp_dir, "interfaces")
  end

  def to_wpa_config(%__MODULE__{
        ctrl_interface: ctrl_interface,
        ssid: ssid,
        psk: psk,
        key_mgmt: key_mgmt
      }) do
    """
    ctrl_interface=#{ctrl_interface}

    network={
      ssid="#{ssid}"
      psk="#{psk}"
      key_mgmt=#{key_mgmt}
    }
    """
  end

  def to_interfaces_config(
        %__MODULE__{
          iface: iface,
          address_method: address_method,
          address_family: address_family
        } = wifi
      ) do
    """
    auto #{iface}
    iface #{iface} #{address_family} #{address_method}
    """ <>
      config_body(wifi)
  end

  def write_wpa_file(wifi) do
    config_contents = to_wpa_config(wifi)
    :ok = NetworkNG.ensure_tmp_dir()

    wpa_file()
    |> File.write(config_contents)
  end

  def write_interfaces_file(wifi) do
    config_contents = to_interfaces_config(wifi)
    :ok = NetworkNG.ensure_tmp_dir()

    interfaces_file()
    |> File.write(config_contents)
  end

  def write_config_file(wifi) do
    with :ok <- write_interfaces_file(wifi),
         :ok <- write_wpa_file(wifi) do
      :ok
    else
      error -> error
    end
  end

  def down(iface \\ "wlan0") do
    case System.cmd("ifdown", ["-i", interfaces_file(), iface], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, 1} -> {:error, error}
    end
  end

  def up(iface \\ "wlan0") do
    case System.cmd("ifup", ["-i", interfaces_file(), iface], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, 1} -> {:error, error}
    end
  end

  defp config_body(%__MODULE__{address_method: :dhcp, iface: iface}) do
    """
        pre-up wpa_supplicant -B -i #{iface} -c #{wpa_file()} -dd
        post-down killall -q wpa_supplicant
    """
  end

  defp config_body(%__MODULE__{
         address_method: :static,
         address: address,
         netmask: netmask,
         broadcast: broadcast,
         network: network
       }) do
    """
      address #{address}
      netmask #{netmask}
      network #{network}
      broadcast #{broadcast}
    """
  end
end
