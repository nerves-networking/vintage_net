defmodule VintageNet.ActivityMonitor.SocketInfo do
  defstruct [:port, :local_address, :foreign_address]

  @type t :: %__MODULE__{
          port: port(),
          local_address: :inet.ip_address(),
          foreign_address: :inet.ip_address()
        }
end
