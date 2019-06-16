defmodule VintageNet.WiFi.WPASupplicant do
  use GenServer

  alias VintageNet.WiFi.WPASupplicantLL
  require Logger

  @moduledoc """

  """

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Initiate a scan of WiFi networks
  """
  def scan(server) do
    GenServer.call(server, :scan)
  end

  @impl true
  def init(args) do
    {:ok, ll} = WPASupplicantLL.start_link(Keyword.get(args, :control_path))
    :ok = WPASupplicantLL.subscribe(ll)

    state = %{
      keep_alive_interval: Keyword.get(args, :keep_alive_interval, 60000),
      ll: ll
    }

    {:ok, state, {:continue, :continue}}
  end

  @impl true
  def handle_continue(:continue, state) do
    {:ok, "OK\n"} = WPASupplicantLL.control_request(state.ll, "ATTACH")
    {:noreply, state, state.keep_alive_interval}
  end

  @impl true
  def handle_info(:timeout, state) do
    {:ok, "PONG\n"} = WPASupplicantLL.control_request(state.ll, "PING")
    {:noreply, state, state.keep_alive_interval}
  end

  def handle_info({VintageNet.WiFi.WPASupplicant, _priority, message}, state) do
    new_state = handle_notification(message, state)
    {:noreply, new_state, new_state.keep_alive_interval}
  end

  defp handle_notification("CTRL-EVENT-BSS-ADDED " <> parameters, state) do
    state
  end

  defp handle_notification(unknown_message, state) do
    _ = Logger.info("WpaSupplicant ignoring #{inspect(unknown_message)}")
    state
  end
end
