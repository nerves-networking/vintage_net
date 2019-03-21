defmodule Nerves.NetworkNG.PPPD do
  @moduledoc """
  Example with Twilio provider

  iex> {:ok, pppd} = Nerves.NetworkNG.setup_with_provider(Nerves.NetworkNG.Twilio)
  iex> Nerves.NetworkNG.up(pppd, "/dev/ttyUSB1")
  """

  # probably will want to handle this differently long term
  @default_pppd_options [
    noipdefault: true,
    usepeerdns: true,
    defaultroute: true,
    persist: true,
    noauth: true
  ]

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

  @doc """
  Takes the pppd provider module (make a behavior for this?) to set
  up configuration file and ensures other systems related things set up.

  Might want to remove particular setup logic out to different
  functions.

  We return a new PPPD to use if setup works.
  """
  @spec setup_with_provider(module(), pppd_options :: keyword()) :: {:ok, t()} | any()
  def setup_with_provider(provider_module, pppd_options \\ @default_pppd_options) do
    with :ok <- apply(provider_module, :write_config, []),
         {"", _} <- System.cmd("mknod", ["/dev/ppp", "c", "108", "0"]) do
      {:ok, new(provider_module, pppd_options)}
    else
      error -> error
    end
  end

  @doc """
  Start the pppd service.

  Takes a PPPD config, the ttyname to connect to, and the speed (default 115_200)
  """
  @spec up(t(), String.t(), non_neg_integer()) :: integer()
  def up(pppd, ttyname, speed \\ 115_200) do
    pppd_command = to_cli_command(pppd, ttyname, speed)
    {_, exit_code} = System.cmd("sh", ["-c", pppd_command])
    exit_code
  end

  @spec to_cli_command(t(), String.t(), non_neg_integer()) :: String.t()
  def to_cli_command(
        %__MODULE__{provider: provider_module} = pppd,
        ttyname,
        speed
      ) do
    provider_config_file = apply(provider_module, :config_file_path, [])

    pppd_opts_string =
      pppd
      |> to_option_list()
      |> Enum.map(&option_to_string/1)
      |> Enum.join(" ")

    "pppd connect \"/usr/sbin/chat -v -f #{provider_config_file}\" #{ttyname} #{speed} #{
      pppd_opts_string
    }"
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
