defmodule VintageNet.OSEventDispatcher.UdhcpcHandler do
  @moduledoc false

  # A private behaviour for handling notifications from udhcpc
  #
  # ## Example
  #
  # ```elixir
  # defmodule MyApp.UdhcpcHandler do
  #   @behaviour VintageNet.OSEventDispatcher.UdhcpcHandler
  #
  #   @impl VintageNet.OSEventDispatcher.UdhcpcHandler
  #   def deconfig(ifname, data) do
  #     ...
  #   end
  # end
  # ```
  #
  # To have VintageNet invoke it, add the following to your `config.exs`:
  #
  # ```elixir
  # config :vintage_net, udhcpc_handler: MyApp.UdhcpcHandler
  # ```

  alias VintageNet.DHCP.Options

  @doc """
  Deconfigure the specified interface
  """
  @callback deconfig(VintageNet.ifname(), Options.t()) :: :ok

  @doc """
  Handle a failure to get a lease
  """
  @callback leasefail(VintageNet.ifname(), Options.t()) :: :ok

  @doc """
  Handle a DHCP NAK
  """
  @callback nak(VintageNet.ifname(), Options.t()) :: :ok

  @doc """
  Handle the renewal of a DHCP lease
  """
  @callback renew(VintageNet.ifname(), Options.t()) :: :ok

  @doc """
  Handle an assignment from the DHCP server
  """
  @callback bound(VintageNet.ifname(), Options.t()) :: :ok
end
