defmodule Nerves.NetworkNG.AccessPoint do
  alias Nerves.NetworkNG.{HostAPD, WiFi, DNSMASQ}

  defstruct interface: nil,
            ssid: nil,
            psk: nil,
            address: nil,
            dhcp_range_min: nil,
            dhcp_range_max: nil,
            netmask: nil,
            network: nil,
            broadcast: nil

  def new(opts) do
    struct(__MODULE__, opts)
  end

  def write_config_files(ap) do
    with :ok <- config_wifi(ap),
         :ok <- config_dnsmasq(ap),
         :ok <- config_hostapd(ap) do
      :ok
    end
  end

  def up() do
    with :ok <- WiFi.up(),
         :ok <- DNSMASQ.run(),
         :ok <- HostAPD.run() do
      :ok
    else
      error -> error
    end
  end

  def config_wifi(
        %__MODULE__{
          interface: interface,
          ssid: ssid,
          psk: psk,
          address: address,
          network: network,
          netmask: netmask,
          broadcast: broadcast
        },
        opts \\ []
      ) do
    opts =
      [
        address: address,
        network: network,
        netmask: netmask,
        address_method: :static,
        broadcast: broadcast
      ]
      |> Keyword.merge(opts)

    interface
    |> WiFi.new(ssid, psk, opts)
    |> WiFi.write_config_file()
  end

  def config_hostapd(
        %__MODULE__{
          interface: interface,
          ssid: ssid,
          psk: psk
        },
        opts \\ []
      ) do
    interface
    |> HostAPD.new(ssid, psk, opts)
    |> HostAPD.write_config_file()
  end

  def config_dnsmasq(
        %__MODULE__{
          interface: interface,
          address: address,
          dhcp_range_min: dhcp_range_min,
          dhcp_range_max: dhcp_range_max
        },
        opts \\ []
      ) do
    interface
    |> DNSMASQ.new(address, dhcp_range_min, dhcp_range_max, opts)
    |> DNSMASQ.write_config_file()
  end
end
