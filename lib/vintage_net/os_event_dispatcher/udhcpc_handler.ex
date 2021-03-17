defmodule VintageNet.OSEventDispatcher.UdhcpcHandler do
  @moduledoc """
  A behaviour for handling notifications from udhcpc

  ## Example

  ```elixir
  defmodule MyApp.UdhcpcHandler do
    @behaviour VintageNet.OSEventDispatcher.UdhcpcHandler

    @impl VintageNet.OSEventDispatcher.UdhcpcHandler
    def deconfig(ifname, data) do
      ...
    end
  end
  ```

  To have VintageNet invoke it, add the following to your `config.exs`:

  ```elixir
  config :vintage_net, udhcpc_handler: MyApp.UdhcpcHandler
  ```
  """

  @typedoc """
  Update data is the unmodified environment variable strings from udhcpc

  The following is an example of update data, but it really depends
  on what udhcpc wants to send:

  ```elixir
  %{
    "broadcast" => "192.168.7.255",
    "dns" => "192.168.7.1",
    "domain" => "hunleth.lan",
    "hostname" => "nerves-9780",
    "interface" => "eth0",
    "ip" => "192.168.7.190",
    "lease" => "86400",
    "mask" => "24",
    "opt53" => "05",
    "opt58" => "0000a8c0",
    "opt59" => "00012750",
    "router" => "192.168.7.1",
    "serverid" => "192.168.7.1",
    "siaddr" => "192.168.7.1",
    "subnet" => "255.255.255.0"
  }
  ```
  """
  @type update_data :: %{String.t() => String.t()}

  @doc """
  Deconfigure the specified interface
  """
  @callback deconfig(VintageNet.ifname(), update_data()) :: :ok

  @doc """
  Handle a failure to get a lease
  """
  @callback leasefail(VintageNet.ifname(), update_data()) :: :ok

  @doc """
  Handle a DHCP NAK
  """
  @callback nak(VintageNet.ifname(), update_data()) :: :ok

  @doc """
  Handle the renewal of a DHCP lease
  """
  @callback renew(VintageNet.ifname(), update_data()) :: :ok

  @doc """
  Handle an assignment from the DHCP server
  """
  @callback bound(VintageNet.ifname(), update_data()) :: :ok
end
