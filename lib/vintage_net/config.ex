defmodule VintageNet.Config do
  @doc """
  Builds a vintage network configuration
  """
  def make(networks, opts \\ []) do
    Enum.map(networks, &do_make(&1, opts))
    |> network_list_to_config()
  end

  def get_option(opts, option) do
    case Keyword.fetch(opts, option) do
      :error -> {:error, :option_not_found, option}
      {:ok, _} = result -> result
    end
  end

  defp do_make({ifname, %{type: :ethernet} = config}, opts) do
    with {:ok, ifup} <- get_option(opts, :ifup),
         {:ok, ifdown} <- get_option(opts, :ifdown) do
      %{
        files: [{"/tmp/network_interfaces.#{ifname}", "iface #{ifname} inet dhcp"}],
        up_cmds: ["#{ifup} -i /tmp/network_interfaces.#{ifname} #{ifname}"],
        down_cmds: ["#{ifdown} -i /tmp/network_interfaces.#{ifname} #{ifname}"]
      }
    end
  end

  defp network_list_to_config(networks) do
    files = Enum.reduce(networks, [], fn %{files: nfiles}, files -> files ++ nfiles end)

    up_cmds =
      Enum.reduce(networks, [], fn %{up_cmds: nup_cmds}, up_cmds -> up_cmds ++ nup_cmds end)

    down_cmds =
      Enum.reduce(networks, [], fn %{down_cmds: ndown_cmds}, down_cmds ->
        down_cmds ++ ndown_cmds
      end)

    %{files: files, up_cmds: up_cmds, down_cmds: down_cmds}
  end
end
