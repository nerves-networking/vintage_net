defmodule Nerves.NetworkNG.Interface.LoggerHandle do
  @behaviour Nerves.NetworkNG.Interface.Handle

  require Logger

  @impl Nerves.NetworkNG.Interface.Handle
  def handle_down(interface) do
    Logger.warn("Interface down: #{inspect(interface)}")
  end

  @impl Nerves.NetworkNG.Interface.Handle
  def handle_up(interface) do
    Logger.warn("Interface up: #{inspect(interface)}")
  end

  @impl Nerves.NetworkNG.Interface.Handle
  def handle_info(interface) do
    Logger.info("Interface: #{inspect(interface)}")
  end
end
