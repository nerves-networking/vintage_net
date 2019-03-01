defmodule Nerves.NetworkNG.IP do
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
end
