defmodule VintageNet.InterfaceRenamer.IP do
  @moduledoc false

  @behaviour VintageNet.InterfaceRenamer
  alias VintageNet.Command

  def rename_interface(ifname, rename_to) do
    args = ["link", "set", ifname, "name", rename_to]

    case Command.cmd("ip", args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {message, _error} -> {:error, message}
    end
  end
end
