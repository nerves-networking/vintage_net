defmodule VintageNet.ToElixir.UdhcpcHandler do
  @moduledoc """
  A behaviour for handling notifications from udhcpc


  # Example

  ```elixir
  defmodule MyApp.UdhcpcHandler do
    @behaviour VintageNet.ToElixir.UdhcpcHandler

    @impl true
    def deconfig(data) do
      ...
    end
  end
  ```

  To have NervesHub invoke it, add the following to your `config.exs`:

  ```elixir
  config :vintage_net, udhcpc_handler: MyApp.UdhcpcHandler
  ```
  """

  @type ifname :: String.t()
  @type update_data :: map()

  @doc """
  """
  @callback deconfig(ifname(), update_data()) :: :ok

  @doc """
  """
  @callback leasefail(ifname(), update_data()) :: :ok

  @doc """
  """
  @callback nak(ifname(), update_data()) :: :ok

  @doc """
  """
  @callback renew(ifname(), update_data()) :: :ok

  @doc """
  """
  @callback bound(ifname(), update_data()) :: :ok

  @doc """
  Called internally by vintage_net to dispatch calls
  """
  @spec dispatch(atom(), ifname(), update_data()) :: :ok
  def dispatch(function, ifname, update_data) do
    handler = Application.get_env(:vintage_net, :udhcpc_handler)
    apply(handler, function, [ifname, update_data])
  end
end
