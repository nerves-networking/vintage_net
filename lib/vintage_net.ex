defmodule VintageNet do
  @moduledoc """
  VintageNet configures network interfaces using Linux utilities


  """
  alias VintageNet.{Interface, Persistence}

  @doc """
  Return a list of interface names that have been configured
  """
  @spec get_interfaces() :: [String.t()]
  def get_interfaces() do
    for {[_interface, ifname | _rest], _value} <-
          PropertyTable.get_by_prefix(VintageNet, ["interface"]) do
      ifname
    end
    |> Enum.uniq()
  end

  @doc """
  Update the settings for the specified interface
  """
  @spec configure(String.t(), map()) :: :ok | {:error, any()}
  def configure(ifname, config) do
    # The logic here is to validate the config by converting it to
    # a raw_config. We'd need to do that anyway, so just get it over with.
    # The next step is to persist the config. This is important since
    # if the Interface GenServer ever crashes and restarts, we want it to use this
    # new config. `maybe_start_interface` might start up an Interface
    # GenServer. If it does, then it will reach into reach into Persistence for
    # the config and it would be bad for it to get an old config. If a GenServer
    # isn't started, configure the running one.
    with {:ok, raw_config} <- Interface.to_raw_config(ifname, config),
         :ok <- Persistence.call(:save, [ifname, config]),
         {:error, :already_started} <- maybe_start_interface(ifname) do
      Interface.configure(raw_config)
    end
  end

  @doc """
  Return the settings for the specified interface
  """
  @spec get_configuration(String.t()) :: map()
  def get_configuration(ifname) do
    Interface.get_configuration(ifname)
  end

  @doc """
  Check if this is a valid configuration

  This runs the validation routines for a settings map, but doesn't try
  to apply them.
  """
  @spec configuration_valid?(String.t(), map()) :: boolean()
  def configuration_valid?(ifname, config) do
    case Interface.to_raw_config(ifname, config) do
      {:ok, _raw_config} -> true
      _ -> false
    end
  end

  @doc """
  Scan wireless interface for other access points
  """
  @spec scan(String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def scan(ifname) do
    Interface.ioctl(ifname, :scan)
  end

  @doc """
  Check that the system has the required programs installed

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
