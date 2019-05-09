defmodule VintageNet do
  @moduledoc """
  VintageNet configures network interfaces using Linux utilities


  """
  alias VintageNet.{Interface, Persistence, PropertyTable}

  @type ifname :: String.t()

  @doc """
  Return a list of interface names that have been configured
  """
  @spec get_interfaces() :: [ifname()]
  def get_interfaces() do
    for {[_interface, ifname | _rest], _value} <-
          get_by_prefix(["interface"]) do
      ifname
    end
    |> Enum.uniq()
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

  To get a list of all known properties and their values, call `VintageNet.get_by_prefix([])`
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
  Check that the system has the required programs installed

  TODO!!!!
  """
  @spec verify_system([atom()] | atom(), keyword()) :: :ok | {:error, any()}
  def verify_system(types, opts) when is_list(types) do
    # TODO...Fix with whatever the right Enum thing is.
    with :ok <- verify_system(:ethernet, opts) do
      :ok
    end
  end

  def verify_system(:ethernet, opts) do
    with :ok <- check_program(opts[:bin_ifup]) do
      :ok
    end
  end

  def verify_system(:wifi, opts) do
    with :ok <- check_program(opts[:bin_ifup]) do
      :ok
    end
  end

  def verify_system(:wifi_ap, opts) do
    with :ok <- check_program(opts[:bin_ifup]) do
      :ok
    end
  end

  def verify_system(:mobile, opts) do
    with :ok <- check_program(opts[:bin_ifup]) do
      :ok
    end
  end

  defp check_program(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, "Can't find #{path}"}
    end
  end

  defp maybe_start_interface(ifname) do
    case VintageNet.InterfacesSupervisor.start_interface(ifname) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> {:error, :already_started}
      {:error, other} -> {:error, other}
    end
  end
end
