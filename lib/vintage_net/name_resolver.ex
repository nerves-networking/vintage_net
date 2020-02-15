defmodule VintageNet.NameResolver do
  use GenServer
  alias VintageNet.IP
  alias VintageNet.Resolver.ResolvConf

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

  defmodule State do
    @moduledoc false
    defstruct [:path, :entries]
  end

  @doc """
  Start the resolv.conf manager.
  """
  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(args) do
    resolvconf_path = Keyword.get(args, :resolvconf)
    GenServer.start_link(__MODULE__, resolvconf_path, name: __MODULE__)
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
  @spec setup(String.t(), String.t() | nil, [VintageNet.any_ip_address()]) :: :ok
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

  @impl true
  def init(resolvconf_path) do
    state = %State{path: resolvconf_path, entries: %{}}
    write_resolvconf(state)
    {:ok, state}
  end

  @impl true
  def handle_call({:setup, ifname, domain, name_servers}, _from, state) do
    servers = Enum.map(name_servers, &IP.ip_to_tuple!/1)
    ifentry = %{domain: domain, name_servers: servers}

    state = %{state | entries: Map.put(state.entries, ifname, ifentry)}
    write_resolvconf(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:clear, ifname}, _from, state) do
    state = %{state | entries: Map.delete(state.entries, ifname)}
    write_resolvconf(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear_all, _from, state) do
    state = %{state | entries: %{}}
    write_resolvconf(state)
    {:reply, :ok, state}
  end

  defp write_resolvconf(%State{path: path, entries: entries}) do
    File.write!(path, ResolvConf.to_config(entries))
  end
end
