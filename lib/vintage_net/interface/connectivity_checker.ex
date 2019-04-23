defmodule VintageNet.Interface.ConnectivityChecker do
  use GenServer

  require Logger
  require Record

  @internet_address "nerves-project.org"

  @delay_to_first_check 100
  @interval 5_000

  @doc false
  Record.defrecord(:hostent, Record.extract(:hostent, from_lib: "kernel/include/inet.hrl"))

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
    case ping(ifname) do
      :ok ->
        _ = Logger.debug("PING #{ifname}")

      {:error, reason} ->
        _ = Logger.debug("PANG #{ifname}: #{inspect(reason)}")
    end

    ping_wait(interval)
    {:noreply, state}
  end

  defp ping(ifname) do
    with {:ok, ip} <- resolve_addr(@internet_address),
         {:ok, opts} <- get_tcp_options(ifname),
         {:ok, tcp} <- :gen_tcp.connect(ip, 80, opts) do
      _ = :gen_tcp.close(tcp)
      :ok
    end
  end

  defp get_tcp_options(ifname) do
    ifname_cl = to_charlist(ifname)

    with {:ok, ifaddrs} <- :inet.getifaddrs(),
         {_, params} <- Enum.find(ifaddrs, fn {k, _v} -> k == ifname_cl end),
         addr when is_tuple(addr) <- Keyword.get(params, :addr) do
      {:ok, [{:ip, addr}]}
    else
      _ ->
        {:error, "No IP address on interface"}
    end
  end

  defp resolve_addr(address) do
    with {:ok, hostent} <- :inet.gethostbyname(to_charlist(address)),
         hostent(h_addr_list: ip_list) = hostent,
         first_ip = hd(ip_list) do
      {:ok, first_ip}
    else
      _ -> {:error, "Error resolving #{address}"}
    end
  end

  defp ping_wait(interval) do
    Process.send_after(self(), :ping, interval)
  end
end
