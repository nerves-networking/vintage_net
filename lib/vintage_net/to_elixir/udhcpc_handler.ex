defmodule VintageNet.ToElixir.UdhcpcHandler do
  @moduledoc """
  A behaviour for handling notifications from udhcpc

  ## Example

  ```elixir
  defmodule MyApp.UdhcpcHandler do
    @behaviour VintageNet.ToElixir.UdhcpcHandler

    @impl VintageNet.ToElixir.UdhcpcHandler
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

  @type update_data :: map()

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

  @doc """
  Called internally by vintage_net to dispatch calls
  """
  @spec dispatch(atom(), VintageNet.ifname(), update_data()) :: :ok
  def dispatch(function, ifname, update_data) do
    handler = Application.get_env(:vintage_net, :udhcpc_handler)
    apply(handler, function, [ifname, update_data])
  end
end
