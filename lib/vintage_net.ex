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
  alias VintageNet.{Info, Interface, PropertyTable}

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

  @typedoc """
  IP addresses in VintageNet can be specified as strings or tuples

  While VintageNet uses IP addresses in tuple form internally, it can be
  cumbersome to always convert to tuple form in practice. The general rule is
  that VintageNet is flexible in how it accepts IP addresses, but if you get an
  address from a VintageNet API, it will be in tuple form.
  """
  @type any_ip_address :: String.t() | :inet.ip_address()

  @typedoc """
  The number of IP address bits for the subnet
  """
  @type prefix_length :: ipv4_prefix_length() | ipv6_prefix_length()

  @typedoc """
  The number of bits to use for an IPv4 subnet

  For example, if you have a subnet mask of 255.255.255.0, then the prefix
  length would be 24.
  """
  @type ipv4_prefix_length :: 0..32

  @typedoc """
  The number of bits to use for an IPv6 subnet
  """
  @type ipv6_prefix_length :: 0..128

  @typedoc """
  Valid options for `VintageNet.configure/3`

  * `:persist` - Whether or not to save the configuration (defaults to `true`)
  """
  @type configure_options :: [persist: boolean]

  @typedoc """
  Valid options for `VintageNet.info/1`

  * `:redact` - Whether to hide passwords and similar information from the output (defaults to `true`)
  """
  @type info_options :: {:redact, boolean()}

  @doc """
  Return a list of all interfaces on the system
  """
  @spec all_interfaces() :: [ifname()]
  def all_interfaces() do
    present = VintageNet.match(["interface", :_, "present"])

    for {[_interface, ifname, _present], true} <- present do
      ifname
    end
  end

  @doc """
  Return a list of configured interface
  """
  @spec configured_interfaces() :: [ifname()]
  def configured_interfaces() do
    type = VintageNet.match(["interface", :_, "type"])

    for {[_interface, ifname, _type], value} when value != VintageNet.Technology.Null <- type do
      ifname
    end
  end

  @doc """
  Return the maximum number of interfaces controlled by VintageNet

  Internal constraints mean that VintageNet can't manage an arbitrary number of
  interfaces and knowing the max can reduce some processing. The limit is set
  by the application config. Unless you need over 100 network interfaces,
  VintageNet's use of the Linux networking API is not likely to be an issue,
  though.
  """
  @spec max_interface_count() :: 1..100
  def max_interface_count() do
    Application.get_env(:vintage_net, :max_interface_count)
  end

  @doc """
  Update the configuration of a network interface

  Configurations are validated and normalized before being applied.  This means
  that type errors and missing required fields will be caught and old or
  redundant ways of specifying configurations will be fixed.  Call
  `get_configuration/1` to see how what changes, if any, were made as part of
  the normalization process.

  After validation, the configuration is optionally persisted and applied.

  See the `VintageNet` documentation for configuration examples or your
  `VintageNet.Technology` provider's docs.

  Options:

  * `:persist` - set to `false` to avoid persisting this configuration. System
    restarts will revert to the previous configuration.
  """
  @spec configure(ifname(), map(), configure_options()) :: :ok | {:error, any()}
  def configure(ifname, config, options \\ []) do
    Interface.configure(ifname, config, options)
  end

  @doc """
  Deconfigure settings for a specified interface.

  Supports same options as `configure/3`
  """
  @spec deconfigure(ifname(), configure_options()) :: :ok | {:error, any()}
  def deconfigure(ifname, options \\ []) do
    Interface.deconfigure(ifname, options)
  end

  @doc """
  Return the settings for the specified interface

  If the configuration does not exist return the `default` value.
  """
  @spec get_configuration(ifname(), default :: any()) :: map() | any()
  def get_configuration(ifname, default \\ nil) do
    PropertyTable.get(VintageNet, ["interface", ifname, "config"], default)
  end

  @doc """
  Return the settings for the specified interface

  If the configuration does not exist this will raise a `RuntimeError`.
  """
  @spec get_configuration!(ifname()) :: map()
  def get_configuration!(ifname) do
    PropertyTable.get(VintageNet, ["interface", ifname, "config"]) ||
      raise RuntimeError, "No configuration for #{ifname}"
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

  See `get_by_prefix/1` for exact prefix matches (i.e., get all properties for one
  interface) and `match/1` to run wildcard matches (i.e., get a specific
  property for all interfaces).
  """
  @spec get(PropertyTable.property(), PropertyTable.value()) :: PropertyTable.value()
  def get(name, default \\ nil) do
    PropertyTable.get(VintageNet, name, default)
  end

  @doc """
  Get a list of all properties matching a pattern

  Patterns are list of strings that optionally specify `:_` at
  a position in the list to match any value.
  """
  @spec match(PropertyTable.property_with_wildcards()) :: [
          {PropertyTable.property(), PropertyTable.value()}
        ]
  def match(pattern) do
    PropertyTable.match(VintageNet, pattern)
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
  Subscribe to property change messages

  Messages have the form:

  ```
  {VintageNet, property_name, old_value, new_value, metadata}
  ```

  Subscriptions are prefix matches. For example, to get notified whenever a property
  changes on "wlan0", run this:

  ```
  VintageNet.subscribe(["interface", "wlan0"])
  ```

  It's also possible to match with wildcards using `:_`. For example, to
  get notified whenever an IP address in the system changes, do this:

  ```
  VintageNet.subscribe(["interface", :_, "addresses"])
  ```
  """
  @spec subscribe(PropertyTable.property_with_wildcards()) :: :ok
  def subscribe(name) do
    PropertyTable.subscribe(VintageNet, name)
  end

  @doc """
  Stop subscribing to property change messages
  """
  @spec unsubscribe(PropertyTable.property_with_wildcards()) :: :ok
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
  Initiate an access point scan on a wireless interface

  The scan results are posted asynchronously to the `["interface", ifname, "wifi", "access_points"]`
  property as they come in. It appears that there's some variation in how scanning
  is implemented on WiFi adapters. One strategy that seems to work is to call `scan/1` every
  10 seconds or so while prompting a user to pick a WiFi network.

  This is a utility function for calling the `:scan` ioctl.
  """
  @spec scan(ifname()) :: :ok | {:error, any()}
  def scan(ifname) do
    ioctl(ifname, :scan)
  end

  @doc """
  Print the current network status

  Options include:

  * `:redact` - Set to `false` to print out passwords
  """
  @spec info([info_options()]) :: :ok
  defdelegate info(options \\ []), to: Info

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
end
