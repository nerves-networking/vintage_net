defmodule VintageNet.ToElixir.UdhcpdHandler do
  @moduledoc """
  A behaviour for handling notifications from udhcpd

  ## Example

  ```elixir
  defmodule MyApp.UdhcpdHandler do
    @behaviour VintageNet.ToElixir.UdhcpdHandler

    @impl true
    def lease_update(ifname, report_data) do
      ...
    end
  end
  ```

  To have VintageNet invoke it, add the following to your `config.exs`:

  ```elixir
  config :vintage_net, udhcpd_handler: MyApp.UdhcpdHandler
  ```
  """

  @type update_data :: map()

  @doc """
  The DHCP lease file was updated
  """
  @callback lease_update(VintageNet.ifname(), Path.t()) :: :ok

  @doc """
  Called internally by vintage_net to dispatch calls
  """
  @spec dispatch(atom(), VintageNet.ifname(), Path.t()) :: :ok
  def dispatch(function, ifname, lease_file) do
    handler = Application.get_env(:vintage_net, :udhcpd_handler)
    apply(handler, function, [ifname, lease_file])
  end
end
