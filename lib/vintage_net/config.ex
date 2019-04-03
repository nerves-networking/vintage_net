defmodule VintageNet.Config do
  @doc """
  Builds a vintage network configuration
  """
  def make(networks, opts \\ []) do
    Enum.map(networks, &do_make(&1, opts))
  end

  def get_option(opts, option) do
    case Keyword.fetch(opts, option) do
      :error -> {:error, :option_not_found, option}
      {:ok, _} = result -> result
    end
  end

  defp do_make({ifname, %{type: :ethernet} = _config}, opts) do
    with {:ok, ifup} <- get_option(opts, :ifup),
         {:ok, ifdown} <- get_option(opts, :ifdown) do
      result = %{
        files: [{"/tmp/network_interfaces.#{ifname}", "iface #{ifname} inet dhcp"}],
        up_cmds: ["#{ifup} -i /tmp/network_interfaces.#{ifname} #{ifname}"],
        down_cmds: ["#{ifdown} -i /tmp/network_interfaces.#{ifname} #{ifname}"]
      }

      {ifname, result}
    end
  end
end
