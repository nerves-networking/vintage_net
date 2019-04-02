defmodule VintageNet do
  @moduledoc """
  VintageNet configures network interfaces using Linux utilities


  """

  @typedoc """
  Types of networks supported by VintageNet
  """
  @type network_type :: :ethernet | :wifi | :wifi_ap | :mobile

  @doc """
  Return a list of interface names that have been configured
  """
  def get_configured_interfaces() do
  end

  @doc """
  Return the settings for the specified interface
  """
  @spec get_settings(String.t()) :: {:ok, map()} | {:error, :unconfigured}
  def get_settings(_ifname) do
    {:ok, %{}}
  end

  @doc """
  Update the settings for the specified interface
  """
  @spec update_settings(String.t(), map()) :: :ok | {:error, any()}
  def update_settings(_ifname, _settings) do
    :ok
  end

  @doc """
  Validate settings

  This runs the validation routines for a settings map, but doesn't try
  to apply them.
  """
  @spec validate_settings(map()) :: :ok | {:error, any()}
  def validate_settings(_settings) do
    :ok
  end

  @doc """
  Check that the system has the required programs installed

  """
  @spec verify_system([network_type()] | network_type(), keyword()) :: :ok | {:error, any()}
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
