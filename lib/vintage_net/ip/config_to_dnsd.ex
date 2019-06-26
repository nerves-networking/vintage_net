defmodule VintageNet.IP.ConfigToDnsd do
  @moduledoc """
  """

  @doc """
  Convert a configuration to the commandline arguments to dnsd

  * `:address` - address to listen on (required)
  * `:ttl` - TTL in seconds
  * `:port` - port (default 53)
  """
  @spec config_to_dnsd_args(map(), Path.t()) :: [String.t()]
  def config_to_dnsd_args(%{dnsd: dnsd}, dnsd_conf_path) do
    ["-c", dnsd_conf_path] ++ Enum.flat_map(dnsd, &to_dnsd_arg/1)
  end

  @doc """
  Convert a configuration to the contents of a /etc/dnsd.conf file
  """
  @spec config_to_dnsd_contents(map()) :: String.t()
  def config_to_dnsd_contents(%{dnsd: %{nameservers: nameservers}}) do
    contents =
      Enum.map(nameservers, fn {hostname, address} ->
        "#{hostname} #{address}"
      end)
      |> Enum.join("\n")

    # Ending newline required
    # for dnsd to parse file
    contents <> "\n"
  end

  defp to_dnsd_arg({:ttl, seconds}), do: ["-t", to_string(seconds)]
  defp to_dnsd_arg({:port, port}), do: ["-p", to_string(port)]
  defp to_dnsd_arg({:address, addr}), do: ["-i", to_string(addr)]
  defp to_dnsd_arg(_), do: []
end
