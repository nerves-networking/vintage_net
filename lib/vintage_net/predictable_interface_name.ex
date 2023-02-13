defmodule VintageNet.PredictableInterfaceName do
  @moduledoc """
  Handles predictable interface names by subscribing to the property table and
  renaming matching interface names based on the configuration in application
  environment.
  """
  use GenServer
  alias VintageNet.InterfaceRenamer
  require Logger

  # Linux kernel network prefixes are device dependent, but mostly follow
  # the conventions:
  #
  # * `eth*` - wired Ethernet or not-obviously-p2p connections over USB
  # * `usb*` - point-to-point connections over USB
  # * `wlan*` - wireless LAN
  # * `wwan*` - wireless WAN
  #
  # See https://elixir.bootlin.com/linux/v5.6.15/source/drivers/net/usb/usbnet.c#L1741
  # for a partial discussion in the kernel source.
  @prefixes [
    "eth",
    "usb",
    "wlan",
    "wwan"
  ]

  @typedoc """
  hw_path to a user supplied ifname mapping
  """
  @type hw_path_config() :: %{
          hw_path: Path.t(),
          ifname: VintageNet.ifname()
        }

  @typedoc false
  @type state() :: %{
          ifnames: [hw_path_config()]
        }

  @doc """
  Called before interface configuration.

  First checks if vintage_net is configured to use predictable interface names,
  if so checks the given ifname for "common" naming schemes.

  Instead of a boolean this function returns `:ok` on success, and `{:error,
  not_predictable_interface_name}` on failure. This is done to allow usage in
  `with` chains.
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
    if built_in?(ifname) do
      {:error, :not_predictable_interface_name}
    else
      :ok
    end
  end

  @doc """
  Return whether an ifname is a built-in one

  Built-in names start with `eth`, `wlan`, etc. and cannot be used
  as interfaces names when using the predictable networking feature.

  Examples:

      iex> PredictableInterfaceName.built_in?("wlan0")
      true

      iex> PredictableInterfaceName.built_in?("eth50")
      true

      iex> PredictableInterfaceName.built_in?("lan")
      false
  """
  @spec built_in?(VintageNet.ifname()) :: boolean()
  def built_in?(ifname) do
    Enum.any?(@prefixes, &String.starts_with?(ifname, &1))
  end

  @spec start_link([hw_path_config()]) :: GenServer.on_start()
  def start_link(ifnames) do
    GenServer.start_link(__MODULE__, ifnames, name: __MODULE__)
  end

  @impl GenServer
  # if predictable ifnames are disabled, don't bother
  # starting the server.
  def init([]) do
    :ignore
  end

  def init(ifnames) do
    VintageNet.subscribe(["interface", :_, "hw_path"])
    {:ok, %{ifnames: ifnames, renamed: []}}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "hw_path"], nil, "/devices/virtual", _meta},
        state
      ) do
    Logger.warning("Not renaming #{ifname} because it is a virtual interface")
    {:noreply, state}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "hw_path"], nil, hw_path, _meta},
        state
      ) do
    # checks for duplicates and renames an interface if
    # it matches and no other interface has been renamed
    # by that path already
    state = maybe_rename(state, hw_path, ifname)
    {:noreply, state}
  end

  def handle_info(
        {VintageNet, ["interface", _ifname, "hw_path"], _, nil, _meta},
        state
      ) do
    {:noreply, state}
  end

  # checks the `renamed` list on the state to find anything
  # that was already renamed using this hw_path
  defp is_dupe?(previously_renamed, hw_path) do
    Enum.find(previously_renamed, fn
      %{hw_path: ^hw_path} -> true
      _ -> false
    end) || false
  end

  # this is not a pure function.. it actually causes the rename to happen
  # and returns a new state with the renamed interface
  defp maybe_rename(state, hw_path, ifname) do
    renamed =
      Enum.reduce(state.ifnames, [], fn
        # interface has already been renamed. Ignore.
        %{hw_path: ^hw_path, ifname: ^ifname}, renamed ->
          renamed

        %{hw_path: ^hw_path, ifname: rename_to} = rename, renamed ->
          if is_dupe?(renamed, hw_path) do
            Logger.warning(
              "Not renaming #{ifname} because another interface already matched the hw_path: #{hw_path}"
            )

            renamed
          else
            Logger.debug("VintageNet renaming #{ifname} to #{rename_to}")
            # do side effect..
            :ok = rename(ifname, rename_to)
            [rename | renamed]
          end

        # non matching config
        %{hw_path: _path, ifname: _ifname}, renamed ->
          renamed
      end)

    %{state | renamed: renamed}
  end

  defp rename(ifname, rename_to) do
    InterfaceRenamer.rename(ifname, rename_to)
  end
end
