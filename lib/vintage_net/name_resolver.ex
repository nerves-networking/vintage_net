defmodule VintageNet.NameResolver do
  use GenServer
  alias VintageNet.IP

  @moduledoc """
  This module manages the contents of "/etc/resolv.conf". This file is used
  by the C library for resolving domain names and must be kept up-to-date
  as links go up and down. This module assumes exclusive ownership on
  "/etc/resolv.conf", so if any other code in the system tries to modify the
  file, their changes will be lost on the next update.
  """

  @typedoc "Settings for NameResolver"
  @type ifmap :: %{
          domain: String.t(),
          name_servers: [String.t()]
        }

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

  @typedoc "State of the server."
  @type state :: %{ifname: String.t(), ifmap: ifmap()}

  @impl true
  def init(resolvconf_path) do
    state = %{filename: resolvconf_path, ifmap: %{}}
    write_resolvconf(state)
    {:ok, state}
  end

  @impl true
  def handle_call({:setup, ifname, domain, name_servers}, _from, state) do
    servers = Enum.map(name_servers, &IP.ip_to_string/1)
    ifentry = %{domain: domain, name_servers: servers}

    state = %{state | ifmap: Map.put(state.ifmap, ifname, ifentry)}
    write_resolvconf(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:clear, ifname}, _from, state) do
    state = %{state | ifmap: Map.delete(state.ifmap, ifname)}
    write_resolvconf(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear_all, _from, state) do
    state = %{state | ifmap: %{}}
    write_resolvconf(state)
    {:reply, :ok, state}
  end

  defp domain_text({_ifname, %{domain: domain}}) when is_binary(domain) and domain != "",
    do: ["search ", domain, "\n"]

  defp domain_text(_), do: []

  defp nameserver_text({_ifname, %{name_servers: servers}}) do
    for server <- servers, do: ["nameserver ", server, "\n"]
  end

  defp nameserver_text(_), do: []

  defp resolvconf(ifmap) do
    # Return contents of resolv.conf as iodata
    [Enum.map(ifmap, &domain_text/1), Enum.map(ifmap, &nameserver_text/1)]
  end

  defp write_resolvconf(state) do
    File.write!(state.filename, resolvconf(state.ifmap))
  end
end
