defmodule VintageNet.OSEventDispatcher.UdhcpdHandler do
  @moduledoc false

  # A private behaviour for handling notifications from udhcpd
  #
  # ## Example
  #
  # ```elixir
  # defmodule MyApp.UdhcpdHandler do
  #   @behaviour VintageNet.OSEventDispatcher.UdhcpdHandler
  #
  #   @impl VintageNet.OSEventDispatcher.UdhcpdHandler
  #   def lease_update(ifname, report_data) do
  #     ...
  #   end
  # end
  # ```
  #
  # To have VintageNet invoke it, add the following to your `config.exs`:
  #
  # ```elixir
  # config :vintage_net, udhcpd_handler: MyApp.UdhcpdHandler
  # ```

  @doc """
  The DHCP lease file was updated
  """
  @callback lease_update(VintageNet.ifname(), Path.t()) :: :ok
end
