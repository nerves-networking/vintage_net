defmodule Nerves.NetworkNG.PPPD do
  @moduledoc """
  Example with Twilio provider

  iex> {:ok, pppd} = Nerves.NetworkNG.setup_with_provider(Nerves.NetworkNG.Twilio)
  iex> Nerves.NetworkNG.up(pppd)
  """
  alias Nerves.NetworkNG

  # probably will want to handle this differently long term
  @default_pppd_options [noipdefault: true, usepeerdns: true, defaultroute: true, persist: true]

  @opaque t :: %__MODULE__{
            options: keyword(),
            provider: module()
          }

  defstruct options: [],
            provider: nil

  @spec new(module(), pppd_options :: keyword()) :: t()
  def new(provider_module, pppd_options \\ @default_pppd_options) do
    struct(__MODULE__, provider: provider_module, options: pppd_options)
  end

  def run_usb_modeswitch() do
    NetworkNG.run_cmd("usb_modeswitch", ["-v", "12d1", "-p", "14fe", "-J"])
  end

  @doc """
  Takes the pppd provider module (make a behavior for this?) to set
  up configuration file, runs usb mode switch for the LTE module, and
  setups up kernel drivers

  We return a new PPPD to use if setup works.
  """
  @spec setup_with_provider(module(), pppd_options :: keyword()) :: {:ok, t()} | any()
  def setup_with_provider(provider_module, pppd_options \\ @default_pppd_options) do
    with :ok <- run_usb_modeswitch(),
         :ok <- setup_drivers(),
         :ok <- apply(provider_module, :write_config, []) do
      {:ok, new(provider_module, pppd_options)}
    else
      error -> error
    end
  end

  @doc """
  Start the pppd service.

  Currently will always run the `usb_modeswitch` command, might want to pull that out
  or make it configurable later.
  """
  @spec up(t()) :: integer()
  def up(pppd) do
    {_, exit_code} = System.cmd("sh", ["-c", to_cli_command(pppd)])
    exit_code
  end

  @spec to_cli_command(t()) :: String.t()
  def to_cli_command(%__MODULE__{provider: provider_module} = pppd) do
    provider_config_file = apply(provider_module, :config_file_path, [])

    command_str =
      "pppd connect \"/usr/sbin/chat -v -f #{provider_config_file}\" /dev/ttyUSB0 115200"

    pppd
    |> to_option_list()
    |> Enum.map(&option_to_string/1)
    |> Enum.reduce(command_str, &(&2 <> " #{&1}"))
  end

  def setup_drivers() do
    drivers = [
      "huawei_cdc_ncm",
      "option",
      "bsd_comp",
      "ppp_deflate"
    ]

    Enum.each(drivers, &System.cmd("modprobe", [&1]))
  end

  @spec to_option_list(t()) :: [atom()]
  def to_option_list(%__MODULE__{options: opts}) do
    opts
    |> Enum.reduce([], fn
      {opt_name, true}, acc -> acc ++ [opt_name]
      {_, false}, acc -> acc
    end)
  end

  @spec option_to_string(atom()) :: String.t()
  defp option_to_string(:usepeerdns), do: "usepeerdns"
  defp option_to_string(:defaultroute), do: "defaultroute"
  defp option_to_string(:persist), do: "persist"
  defp option_to_string(:noauth), do: "noauth"
  defp option_to_string(:noipdefault), do: "noipdefault"
end
