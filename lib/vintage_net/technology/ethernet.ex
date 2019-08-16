defmodule VintageNet.Technology.Ethernet do
  @behaviour VintageNet.Technology

  alias VintageNet.Interface.RawConfig
  alias VintageNet.IP.IPv4Config

  @moduledoc """
  Support for common wired Ethernet interface configurations

  Configurations for this technology are maps with a `:type` field set
  to `VintageNet.Technology.Ethernet`. The following additional fields
  are supported:

  * `:ipv4` - IPv4 options. See VintageNet.IP.IPv4Config.

  An example DHCP configuration is:

  ```elixir
  %{type: VintageNet.Technology.Ethernet, ipv4: %{method: :dhcp}}
  ```

  An example static IP configuration is:

  ```elixir
  %{
    type: VintageNet.Technology.Ethernet,
    ipv4: %{
      method: :static,
      address: {192, 168, 0, 5},
      prefix_length: 24,
      gateway: {192, 168, 0, 1}
    }
  }
  ```
  """

  @impl true
  def normalize(%{type: __MODULE__} = config) do
    IPv4Config.normalize(config)
  end

  @impl true
  def to_raw_config(ifname, %{type: __MODULE__} = config, opts) do
    normalized_config = normalize(config)

    %RawConfig{
      ifname: ifname,
      type: __MODULE__,
      source_config: normalized_config
    }
    |> IPv4Config.add_config(normalized_config, opts)
  end

  @impl true
  def ioctl(_ifname, _command, _args) do
    {:error, :unsupported}
  end

  @impl true
  def check_system(opts) do
    # TODO
    with :ok <- check_program(opts[:bin_ifup]) do
      :ok
    end
  end

  defp check_program(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, "Can't find #{path}"}
    end
  end
end
