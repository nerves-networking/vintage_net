defmodule VintageNetTest.TestTechnology do
  @behaviour VintageNet.Technology

  alias VintageNet.Interface.RawConfig

  @moduledoc """
  Support for unit testing APIs that require a Technology behaviour
  """

  @impl true
  def normalize(config) do
    Map.put(config, :normalize_was_called, true)
  end

  @impl true
  def to_raw_config(ifname, config \\ %{}, _opts \\ []) do
    # Let tests inject raw config keys if they specify them.
    # Otherwise, use whatever the defaults are.
    %RawConfig{
      ifname: ifname,
      type: __MODULE__,
      source_config: config,
      required_ifnames: [ifname]
    }
    |> maybe_put(config, [
      :files,
      :require_interface,
      :up_cmds,
      :down_cmds,
      :cleanup_files,
      :retry_millis,
      :up_cmd_millis,
      :down_cmd_millis,
      :child_specs,
      :required_ifnames
    ])
  end

  defp maybe_put(raw_config, config, keys) do
    Enum.reduce(keys, raw_config, &maybe_put_key(&2, config, &1))
  end

  defp maybe_put_key(raw_config, config, key) do
    case Map.fetch(config, key) do
      {:ok, value} ->
        Map.put(raw_config, key, value)

      _ ->
        raw_config
    end
  end

  @impl true
  def ioctl(_ifname, :echo, [what]) do
    # Echo back our argument
    {:ok, what}
  end

  def ioctl(_ifname, :oops, _args) do
    raise "Intentional ioctl oops"
  end

  def ioctl(_ifname, :sleep, [millis]) do
    Process.sleep(millis)
  end

  def ioctl(_ifname, _command, _args) do
    {:error, :unsupported}
  end

  @impl true
  def check_system(_opts) do
    :ok
  end
end
