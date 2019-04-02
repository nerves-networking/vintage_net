defmodule VintageNet.Config do
  @doc """
  Builds a vintage network configuration
  """
  def make(networks, opts \\ []) do
    Enum.reduce(networks, %{}, fn network, _config ->
      do_make(network, opts)
    end)
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

  def get_option(opts, option) do
    case Keyword.fetch(opts, option) do
      :error -> {:error, :option_not_found, option}
      {:ok, _} = result -> result
    end
  end
end
