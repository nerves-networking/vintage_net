defmodule VintageNet.Interface.ConnectivityChecker do
  use GenServer

  alias VintageNet.RouteManager

  require Record

  @delay_to_first_check 100
  @interval 30_000

  @doc false
  Record.defrecord(:hostent, Record.extract(:hostent, from_lib: "kernel/include/inet.hrl"))

  @doc """
  Start the connectivity checker GenServer
  """
  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(ifname) do
    GenServer.start_link(__MODULE__, ifname)
  end

  @impl true
  def init(ifname) do
    ping_wait(@delay_to_first_check)
    {:ok, %{ifname: ifname, interval: @interval}}
  end

  @impl true
  def handle_info(:ping, %{ifname: ifname, interval: interval} = state) do
    connectivity =
      case ping(ifname) do
        :ok ->
          :internet

        {:error, :no_ip_address} ->
          :disabled

        {:error, _reason} ->
          :lan
      end

    set_connectivity(ifname, connectivity)
    ping_wait(interval)
    {:noreply, state}
  end

  defp ping(ifname) do
    internet_host = Application.get_env(:vintage_net, :internet_host)

    with {:ok, src_ip} <- get_interface_address(ifname),
         {:ok, dest_ip} <- resolve_addr(internet_host),
         {:ok, tcp} <- :gen_tcp.connect(dest_ip, 80, ip: src_ip) do
      _ = :gen_tcp.close(tcp)
      :ok
    end
  end

  defp get_interface_address(ifname) do
    ifname_cl = to_charlist(ifname)

    with {:ok, addresses} <- :inet.getifaddrs(),
         {_, params} <- Enum.find(addresses, fn {k, _v} -> k == ifname_cl end),
         address when is_tuple(address) <- Keyword.get(params, :addr) do
      {:ok, address}
    else
      _ ->
        {:error, :no_ip_address}
    end
  end

  defp resolve_addr(address) do
    with {:ok, hostent} <- :inet.gethostbyname(to_charlist(address)),
         hostent(h_addr_list: ip_list) = hostent,
         first_ip = hd(ip_list) do
      {:ok, first_ip}
    else
      _ -> {:error, :no_dns}
    end
  end

  defp ping_wait(interval) do
    Process.send_after(self(), :ping, interval)
  end

  defp set_connectivity(ifname, connectivity) do
    RouteManager.set_connection_status(ifname, connectivity)
    PropertyTable.put(VintageNet, ["interface", ifname, "connection"], connectivity)
  end
end
