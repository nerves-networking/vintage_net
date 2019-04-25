defmodule VintageNet.Interface.RawConfig do
  @moduledoc """
  Raw configuration for an interface

  This struct contains the low-level instructions for how to configure and
  unconfigure an interface.

  Fields:

  * `ifname` - the name of the interface (e.g., `"eth0"`)
  * `files` - a list of file path, content tuples
  * `up_cmd_millis` - the maximum amount of time to allow the up command list to take
  * `up_cmds` - a list of commands to run to configure the interface
  * `down_cmd_millis` - the maximum amount of time to allow the down command list to take
  * `down_cmds` - a list of commands to run to unconfigure the interface

  """

  @type command :: {:run, String.t(), [String.t()]}
  @type file_contents :: {Path.t(), String.t()}

  @enforce_keys [:ifname]
  defstruct ifname: nil,
            files: [],
            up_cmd_millis: 5_000,
            up_cmds: [],
            down_cmd_millis: 5_000,
            down_cmds: []

  @type t :: %__MODULE__{
          ifname: String.t(),
          files: [file_contents()],
          up_cmd_millis: non_neg_integer(),
          up_cmds: [command()],
          down_cmd_millis: non_neg_integer(),
          down_cmds: [command()]
        }
end
