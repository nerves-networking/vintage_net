defmodule VintageNet.IP do
  def link(args \\ []) do
    case System.cmd("ip", ["link"] ++ args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {error, 1} -> {:error, error}
    end
  end

  def address_show(iface_name) do
    case System.cmd("ip", ["address", "show", iface_name], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {error, _} -> {:error, error}
    end
  end

  def iface_flags(iface) do
    case address_show(iface) do
      {:ok, iface_info_string} ->
        Regex.scan(~r/(?<=\<).*(?=\>)/, iface_info_string)
        |> List.flatten()
        |> Enum.flat_map(&String.split(&1, ","))
        |> Enum.reduce([], fn
          "UP", flags -> flags ++ [:up]
          "LOWER_UP", flags -> flags ++ [:lower_up]
          _, flags -> flags
        end)

      {:error, _} = reason ->
        reason
    end
  end
end
