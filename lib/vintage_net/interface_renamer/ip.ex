# SPDX-FileCopyrightText: 2020 Connor Rigby
# SPDX-FileCopyrightText: 2020 Matt Ludwigs
# SPDX-FileCopyrightText: 2021 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.InterfaceRenamer.IP do
  @moduledoc false

  @behaviour VintageNet.InterfaceRenamer
  alias VintageNet.Command

  @spec rename_interface(VintageNet.ifname(), VintageNet.ifname()) :: :ok | {:error, String.t()}
  def rename_interface(ifname, rename_to) do
    args = ["link", "set", ifname, "name", rename_to]

    case Command.cmd("ip", args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {message, _error} -> {:error, message}
    end
  end
end
