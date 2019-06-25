defmodule VintageNet.Interface.ConnectivityChecker do
  use GenServer
  require Logger

  alias VintageNet.{PropertyTable, RouteManager}
  alias VintageNet.Interface.InternetTester

  @min_interval 500
  @max_interval 30_000
  @max_fails_in_a_row 3

  @doc """
  Start the connectivity checker GenServer
  """
  @spec start_link(VintageNet.ifname()) :: GenServer.on_start()
  def start_link(ifname) do
    GenServer.start_link(__MODULE__, ifname)
  end

  @impl true
  def init(ifname) do
    state = %{ifname: ifname, strikes: @max_fails_in_a_row, interval: @min_interval}
    {:ok, state, {:continue, :continue}}
  end

  @impl true
  def handle_continue(:continue, %{ifname: ifname} = state) do
    VintageNet.subscribe(lower_up_property(ifname))

    set_connectivity(ifname, :disconnected)

    case VintageNet.get(lower_up_property(ifname)) do
      true ->
        {:noreply, state, @min_interval}

      _not_true ->
        # If the physical layer isn't up, don't start polling until
        # we're notified that it is available.
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:timeout, %{ifname: ifname, strikes: strikes, interval: interval} = state) do
    {connectivity, new_strikes} =
      case InternetTester.ping(ifname) do
        :ok ->
          # Success - reset the number of strikes to stay in Internet mode
          # even if there are hiccups.
          {:internet, 0}

        {:error, :if_not_found} ->
          {:disconnected, @max_fails_in_a_row}

        {:error, :no_ipv4_address} ->
          {:disconnected, @max_fails_in_a_row}

        {:error, reason} ->
          if strikes < @max_fails_in_a_row do
            _ =
              Logger.debug(
                "#{ifname}: Internet test failed (#{inspect(reason)}: #{strikes + 1}/#{
                  @max_fails_in_a_row
                } strikes"
              )

            {:internet, strikes + 1}
          else
            _ = Logger.debug("#{ifname}: Internet test failed: (#{inspect(reason)})")
            {:lan, @max_fails_in_a_row}
          end
      end

    next_state = %{
      state
      | strikes: new_strikes,
        interval: next_interval(connectivity, interval, strikes)
    }

    set_connectivity(ifname, connectivity)

    {:noreply, next_state, next_state.interval}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, false, _meta},
        %{ifname: ifname} = state
      ) do
    # Physical layer is down. We're definitely disconnected, so skip right to it and
    # don't poll until the lower_up changes
    set_connectivity(ifname, :disconnected)
    {:noreply, state}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "lower_up"], _old_value, true, _meta},
        %{ifname: ifname} = state
      ) do
    # Physical layer is up. Optimistically assume that the LAN is accessible and
    # start polling again after a short delay
    set_connectivity(ifname, :lan)

    new_state = %{state | interval: @min_interval}
    {:noreply, new_state, @min_interval}
  end

  defp set_connectivity(ifname, connectivity) do
    RouteManager.set_connection_status(ifname, connectivity)
    PropertyTable.put(VintageNet, ["interface", ifname, "connection"], connectivity)
  end

  defp lower_up_property(ifname) do
    ["interface", ifname, "lower_up"]
  end

  # If pings work, then wait the max interval before checking again
  defp next_interval(:internet, _interval, 0), do: @max_interval

  # If a ping fails, retry, but don't wait as long as when everything is working
  defp next_interval(:internet, _interval, strikes) do
    max(@min_interval, @max_interval / (strikes + 1))
  end

  # Back off of checks if they're not working
  defp next_interval(_not_internet, interval, _strikes) do
    min(interval * 2, @max_interval)
  end
end
