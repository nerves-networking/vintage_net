defmodule VintageNet do
  @moduledoc """
  VintageNet configures network interfaces using Linux utilities


  """
  alias VintageNet.Interface

  @doc """
  Return a list of interface names that have been configured
  """
  @spec get_interfaces() :: [String.t()]
  def get_interfaces() do
    []
  end

  @doc """
  Update the settings for the specified interface
  """
  @spec configure(String.t(), map()) :: :ok | {:error, any()}
  def configure(ifname, config) do
    opts = Application.get_all_env(:vintage_net)

    with {:ok, technology} <- Map.fetch(config, :type),
         {:ok, raw_config} <- technology.to_raw_config(ifname, config, opts) do
      Interface.configure(raw_config)
    else
      :error -> {:error, "config requires type field"}
    end
  end

  @doc """
  Return the settings for the specified interface
  """
  @spec get_configuration(String.t()) :: {:ok, map()} | {:error, :unconfigured}
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
    case ifname.type.to_raw_config(ifname, config, []) do
      {:ok, _} -> true
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
end
