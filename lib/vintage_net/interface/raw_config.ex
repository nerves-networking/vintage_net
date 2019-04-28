defmodule VintageNet.Interface.RawConfig do
  @moduledoc """
  Raw configuration for an interface

  This struct contains the low-level instructions for how to configure and
  unconfigure an interface.

  Fields:

  * `ifname` - the name of the interface (e.g., `"eth0"`)
  * `type` - the type of network interface (aka the module that created the config)
  * `source_config` - the configuration that generated this one
  * `retry_millis` - if bringing the interface up fails, wait this amount of time before retrying
  * `files` - a list of file path, content tuples
  * `up_cmd_millis` - the maximum amount of time to allow the up command list to take
  * `up_cmds` - a list of commands to run to configure the interface
  * `down_cmd_millis` - the maximum amount of time to allow the down command list to take
  * `down_cmds` - a list of commands to run to unconfigure the interface
  * `ioctl` a function that handles non-configuration commands when configured

  """

  # Should this just be a function??? The down side is that it's less testable since functions are opaque.
  @type command :: {:run, String.t(), [String.t()]} | {:fun, function()}
  @type file_contents :: {Path.t(), String.t()}

  @enforce_keys [:ifname, :type]
  defstruct ifname: nil,
            type: nil,
            source_config: %{},
            retry_millis: 1_000,
            files: [],
            child_specs: [],
            up_cmd_millis: 5_000,
            up_cmds: [],
            down_cmd_millis: 5_000,
            down_cmds: []

  @type t :: %__MODULE__{
          ifname: String.t(),
          type: atom(),
          source_config: map(),
          retry_millis: non_neg_integer(),
          files: [file_contents()],
          child_specs: [Supervisor.child_spec()],
          up_cmd_millis: non_neg_integer(),
          up_cmds: [command()],
          down_cmd_millis: non_neg_integer(),
          down_cmds: [command()]
        }

  def unimplemented_ioctl(_, _), do: {:error, :unimplemented}
end
