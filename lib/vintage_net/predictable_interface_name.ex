defmodule VintageNet.PredictableInterfaceName do
  @moduledoc """
  Handles predictable interface names by subscribing to the
  property table and renaming matching interface names
  based on the configuration in application env
  """

  use GenServer
  require Logger
  alias VintageNet.InterfaceRenamer

  @prefixes [
    "wlan",
    "eth",
    "usb",
    "ppp"
  ]

  @typedoc """
  Configuration for mapping a hw_path to
  a user supplied ifname
  """
  @type hw_path_config() :: %{
          hw_path: Path.t(),
          ifname: VintageNet.ifname()
        }

  @type state() :: %{
          ifnames: [hw_path_config()]
        }

  @doc """
  Called before interface configuration.
  First checks if vintage_net is configured to
  use predictable interface names, if so checks
  the given ifname for "common" naming schemes.

  Instead of a boolean this function returns
  `:ok` on success, and `{:error, not_predictable_interface_name}`
  on failure. This is done to allow usage in `with` chains.
  """
  @spec precheck(VintageNet.ifname()) :: :ok | {:error, :not_predictable_interface_name}
  def precheck(ifname) do
    # if the `ifnames` property exists, actually run the check.
    if Application.get_env(:vintage_net, :ifnames) do
      do_precheck(ifname)
    else
      :ok
    end
  end

  defp do_precheck(ifname) do
    if Enum.any?(@prefixes, &String.starts_with?(&1, ifname)) do
      {:error, :not_predictable_interface_name}
    else
      :ok
    end
  end

  @spec start_link([hw_path_config()]) :: GenServer.on_start()
  def start_link(ifnames) do
    GenServer.start_link(__MODULE__, ifnames, name: __MODULE__)
  end

  @impl GenServer
  # if predictable ifnaming is disabled, don't bother
  # starting the server.
  def init([]) do
    :ignore
  end

  def init(ifnames) do
    VintageNet.subscribe(["interface", :_, "hw_path"])
    {:ok, %{ifnames: ifnames}}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "hw_path"], nil, hw_path, _meta},
        state
      ) do
    Enum.each(state.ifnames, fn
      # interface has already been renamed. Ignore.
      %{hw_path: ^hw_path, ifname: ^ifname} ->
        :ok

      %{hw_path: ^hw_path, ifname: rename_to} ->
        Logger.debug("VintageNet renaming #{ifname} to #{rename_to}")
        rename(ifname, rename_to)

      # non matching config
      %{hw_path: _path, ifname: _ifname} ->
        :ok
    end)

    {:noreply, state}
  end

  def handle_info(
        {VintageNet, ["interface", _ifname, "hw_path"], _, nil, _meta},
        state
      ) do
    {:noreply, state}
  end

  defp rename(ifname, rename_to) do
    InterfaceRenamer.rename(ifname, rename_to)
  end
end
