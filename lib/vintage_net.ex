defmodule VintageNet do
  @moduledoc """
  `VintageNet` is network configuration library built specifically for [Nerves
  Project](https://nerves-project.org) devices. It has the following features:

  * Ethernet and WiFi support included. Extendible to other technologies
  * Default configurations specified in your Application config
  * Runtime updates to configurations are persisted and applied on next boot (can
    be disabled)
  * Simple subscription to network status change events
  * Connect to multiple networks at a time and prioritize which interfaces are
    used (Ethernet over WiFi over cellular)
  * Internet connection monitoring and failure detection (currently slow and
    simplistic)

  See
  [github.com/nerves-networking/vintage_net](https://github.com/nerves-networking/vintage_net)
  for more information.
  """
  alias VintageNet.{Interface, Persistence, PropertyTable}

  @typedoc """
  A name for the network interface

  Names depend on the device drivers and any software that may rename them.
  Typical names on Nerves are:

  * "eth0", "eth1", etc. for wired Ethernet interfaces
  * "wlan0", etc. for WiFi interfaces
  * "ppp0" for cellular modems
  * "usb0" for gadget USB virtual Ethernet interfaces
  """
  @type ifname :: String.t()

  @doc """
  Return a list of all interfaces on the system

  NOTE: This list is currently updated every 30 seconds rather than on change.
        Be patient.
  """
  @spec all_interfaces() :: [ifname()]
  def all_interfaces() do
    for {["interface", ifname, "present"], true} <-
          get_by_prefix(["interface"]) do
      ifname
    end
  end

  @doc """
  Return a list of configured interface
  """
  @spec configured_interfaces() :: [ifname()]
  def configured_interfaces() do
    for {["interface", ifname, "type"], _value} <-
          get_by_prefix(["interface"]) do
      ifname
    end
  end

  @doc """
  Update the settings for the specified interface
  """
  @spec configure(ifname(), map()) :: :ok | {:error, any()}
  def configure(ifname, config) do
    # The logic here is to validate the config by converting it to a
    # raw_config. We'd need to do that anyway, so just get it over with.  The
    # next step is to persist the config. This is important since if the
    # Interface GenServer ever crashes and restarts, we want it to use this new
    # config. `maybe_start_interface` might start up an Interface GenServer. If
    # it does, then it will reach into reach into Persistence for the config
    # and it would be bad for it to get an old config. If a GenServer isn't
    # started, configure the running one.
    with {:ok, raw_config} <- Interface.to_raw_config(ifname, config),
         :ok <- Persistence.call(:save, [ifname, config]),
         {:error, :already_started} <- maybe_start_interface(ifname) do
      Interface.configure(raw_config)
    end
  end

  @doc """
  Return the settings for the specified interface
  """
  @spec get_configuration(ifname()) :: map()
  def get_configuration(ifname) do
    Interface.get_configuration(ifname)
  end

  @doc """
  Check if this is a valid configuration

  This runs the validation routines for a settings map, but doesn't try to
  apply them.
  """
  @spec configuration_valid?(ifname(), map()) :: boolean()
  def configuration_valid?(ifname, config) do
    case Interface.to_raw_config(ifname, config) do
      {:ok, _raw_config} -> true
      _ -> false
    end
  end

  @doc """
  Get the current value of a network property

  See `get_by_prefix/1` to get some or all properties.
  """
  @spec get(PropertyTable.property(), PropertyTable.value()) :: PropertyTable.value()
  def get(name, default \\ nil) do
    PropertyTable.get(VintageNet, name, default)
  end

  @doc """
  Get a list of all properties matching the specified prefix

  To get a list of all known properties and their values, call
  `VintageNet.get_by_prefix([])`
  """
  @spec get_by_prefix(PropertyTable.property()) :: [
          {PropertyTable.property(), PropertyTable.value()}
        ]
  def get_by_prefix(prefix) do
    PropertyTable.get_by_prefix(VintageNet, prefix)
  end

  @doc """
  Subscribe to receive property change messages

  Messages have the form:

  ```
  {VintageNet, property_name, old_value, new_value, metadata}
  ```
  """
  @spec subscribe(PropertyTable.property()) :: :ok
  def subscribe(name) do
    PropertyTable.subscribe(VintageNet, name)
  end

  @doc """
  Stop subscribing to property change messages
  """
  @spec unsubscribe(PropertyTable.property()) :: :ok
  def unsubscribe(name) do
    PropertyTable.unsubscribe(VintageNet, name)
  end

  @doc """
  Run a command on a network interface

  Commands are mostly network interface-specific. Also see the `VintageNet`
  PropertyTable fo getting status or registering for status changes.
  """
  @spec ioctl(ifname(), atom(), any()) :: :ok | {:ok, any()} | {:error, any()}
  def ioctl(ifname, command, args \\ []) do
    Interface.ioctl(ifname, command, args)
  end

  @doc """
  Scan wireless interface for other access points

  This is a utility function for calling the `:scan` ioctl.
  """
  @spec scan(ifname()) :: {:ok, [VintageNet.WiFi.AccessPoint.t()]} | {:error, any()}
  def scan(ifname) do
    ioctl(ifname, :scan)
  end

  @doc """
  Print the current network status
  """
  @spec info() :: :ok
  def info() do
    version = :application.loaded_applications() |> List.keyfind(:vintage_net, 0) |> elem(2)

    IO.write("""
    VintageNet #{version}

    All interfaces:       #{inspect(all_interfaces())}
    Available interfaces: #{inspect(get(["available_interfaces"]))}
    """)

    ifnames = configured_interfaces()

    if ifnames == [] do
      IO.puts("\nNo configured interfaces")
    else
      Enum.each(ifnames, fn ifname ->
        IO.puts("\nInterface #{ifname}")
        print_if_attribute(ifname, "type", "Type")
        print_if_attribute(ifname, "present", "Present")
        print_if_attribute(ifname, "state", "State")
        print_if_attribute(ifname, "connection", "Connection")
      end)
    end
  end

  defp print_if_attribute(ifname, name, print_name) do
    value = get(["interface", ifname, name])
    IO.puts("  #{print_name}: #{inspect(value)}")
  end

  @doc """
  Check that the system has the required programs installed

  NOTE: This isn't completely implemented yet!
  """
  @spec verify_system(keyword() | nil) :: :ok | {:error, String.t()}
  def verify_system(opts \\ nil) do
    opts = opts || Application.get_all_env(:vintage_net)

    for ifname <- configured_interfaces() do
      type = get(["interface", ifname, "type"])
      apply(type, :check_system, [opts])
    end
    |> Enum.find(:ok, fn rc -> rc != :ok end)
  end

  defp maybe_start_interface(ifname) do
    case VintageNet.InterfacesSupervisor.start_interface(ifname) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> {:error, :already_started}
      {:error, other} -> {:error, other}
    end
  end
end
