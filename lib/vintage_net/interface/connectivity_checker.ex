defmodule VintageNet.Interface.ConnectivityChecker do
  use GenServer

  require Logger
  require Record

  @doc false
  Record.defrecord(:hostent, Record.extract(:hostent, from_lib: "kernel/include/inet.hrl"))

  def start_link(ifname) do
    GenServer.start_link(__MODULE__, ifname)
  end

  def init(ifname) do
    case resolve_addr("nerves-project.org") do
      {:ok, ip} ->
        ping_wait(5_000)
        {:ok, %{ifname: ifname, interval: 5_000, host_ip: ip}}

      {:error, error} ->
        {:stop, error}
    end
  end

  def handle_info(:ping, %{ifname: ifname, interval: interval, host_ip: ip} = state) do
    opts = get_tcp_options(ifname)

    case :gen_tcp.connect(ip, 80, opts) do
      {:ok, pid} ->
        :gen_tcp.close(pid)
        Logger.debug("PING #{ifname}")
        ping_wait(interval)

      {:error, :econnrefused} ->
        Logger.debug("PING #{ifname}")
        ping_wait(interval)

      error ->
        Logger.error("#{inspect(error)}")
    end

    {:noreply, state}
  end

  def get_tcp_options(ifname) do
    ifname_cl = to_charlist(ifname)

    with {:ok, ifaddrs} <- :inet.getifaddrs(),
         {_, params} <- Enum.find(ifaddrs, fn {k, _v} -> k == ifname_cl end),
         addr when is_tuple(addr) <- Keyword.get(params, :addr) do
      [{:ip, addr}]
    else
      _ ->
        # HACK: Give an IP address that will give an address error so
        # that if the interface appears that it will work.
        [{:ip, {1, 2, 3, 4}}]
    end
  end

  def resolve_addr(address) do
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
