defmodule VintageNet.NameResolver do
  use GenServer

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
          nameservers: [String.t()]
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
  Set the search domain and nameserver list for the specified interface.

  This replaces any entries in the `/etc/resolv.conf` for this interface.
  """
  @spec setup(String.t(), String.t(), [String.t()]) :: :ok
  def setup(ifname, domain, nameservers) do
    GenServer.call(__MODULE__, {:setup, ifname, domain, nameservers})
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
  def handle_call({:setup, ifname, domain, nameservers}, _from, state) do
    ifentry = %{domain: domain, nameservers: nameservers}
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

  defp domain_text({_ifname, %{:domain => domain}}) when domain != "", do: "search #{domain}\n"
  defp domain_text(_), do: ""

  defp nameserver_text({_ifname, %{:nameservers => nslist}}) do
    for ns <- nslist, do: "nameserver #{ns}\n"
  end

  defp nameserver_text(_), do: ""

  defp write_resolvconf(state) do
    domains = Enum.map(state.ifmap, &domain_text/1)
    nameservers = Enum.map(state.ifmap, &nameserver_text/1)
    File.write!(state.filename, domains ++ nameservers)
  end
end
