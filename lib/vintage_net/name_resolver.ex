defmodule VintageNet.NameResolver do
  @moduledoc """
  This module manages the contents of "/etc/resolv.conf".

  This file is used by the C standard library and by Erlang for resolving
  domain names.  Since both C programs and Erlang can do resolution, debugging
  problems in this area can be confusing due to varying behavior based on who's
  resolving at the time. See the `/etc/erl_inetrc` file on the target to review
  Erlang's configuration.

  This module assumes exclusive ownership on "/etc/resolv.conf", so if any
  other code in the system tries to modify the file, their changes will be lost
  on the next update.

  It is expected that each network interface provides a configuration. This
  module will track configurations to network interfaces so that it can reflect
  which resolvers are around. Resolver order isn't handled.
  """
  use GenServer
  alias VintageNet.IP
  alias VintageNet.Resolver.ResolvConf
  require Logger

  @type state() :: %{
          path: String.t(),
          entries: ResolvConf.entry_map(),
          additional_name_servers: ResolvConf.additional_name_servers()
        }

  @doc """
  Start the resolv.conf manager.

  Accepted args:

  * `resolvconf` - path to the resolvconf file
  * `additional_name_servers` - list of additional servers
  """
  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(args) do
    relevant_args = Keyword.take(args, [:resolvconf, :additional_name_servers])
    GenServer.start_link(__MODULE__, relevant_args, name: __MODULE__)
  end

  @doc """
  Stop the resolv.conf manager.
  """
  @spec stop() :: :ok
  def stop() do
    GenServer.stop(__MODULE__)
  end

  @doc """
  Set the search domain and name server list for the specified interface.

  This replaces any entries in the `/etc/resolv.conf` for this interface.
  """
  @spec setup(String.t(), String.t() | nil, [:inet.ip_address()]) :: :ok
  def setup(ifname, domain, name_servers) do
    GenServer.call(__MODULE__, {:setup, ifname, domain, name_servers})
  end

  @doc """
  Clear all entries in "/etc/resolv.conf" that are associated with
  the specified interface.
  """
  @spec clear(String.t()) :: :ok
  def clear(ifname) do
    GenServer.call(__MODULE__, {:clear, ifname})
  end

  @doc """
  Completely clear out "/etc/resolv.conf".
  """
  @spec clear_all() :: :ok
  def clear_all() do
    GenServer.call(__MODULE__, :clear_all)
  end

  ## GenServer

  @impl GenServer
  def init(args) do
    resolvconf_path = Keyword.get(args, :resolvconf)

    additional_name_servers =
      Keyword.get(args, :additional_name_servers, [])
      |> Enum.reduce([], &ip_to_tuple_safe/2)
      |> Enum.reverse()

    state = %{
      path: resolvconf_path,
      entries: %{},
      additional_name_servers: additional_name_servers
    }

    refresh(state)
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:setup, ifname, domain, name_servers}, _from, state) do
    ifentry = %{domain: domain, name_servers: name_servers}

    state = %{state | entries: Map.put(state.entries, ifname, ifentry)}
    refresh(state)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:clear, ifname}, _from, state) do
    state = %{state | entries: Map.delete(state.entries, ifname)}
    refresh(state)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:clear_all, _from, state) do
    state = %{state | entries: %{}}
    refresh(state)
    {:reply, :ok, state}
  end

  defp refresh(%{
         path: path,
         entries: entries,
         additional_name_servers: additional_name_servers
       }) do
    # Update the resolv.conf file
    File.write!(path, ResolvConf.to_config(entries, additional_name_servers))

    # Let VintageNet users know the latest
    PropertyTable.put(
      VintageNet,
      ["name_servers"],
      ResolvConf.to_name_server_list(entries, additional_name_servers)
    )
  end

  @spec ip_to_tuple_safe(VintageNet.any_ip_address(), [:inet.ip_address()]) :: [
          :inet.ip_address()
        ]
  defp ip_to_tuple_safe(ip, acc) do
    case IP.ip_to_tuple(ip) do
      {:error, reason} ->
        Logger.error("Failed to parse IP address: #{inspect(ip)} (#{reason})")
        acc

      {:ok, ip} ->
        [ip | acc]
    end
  end
end
