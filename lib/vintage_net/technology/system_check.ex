defmodule VintageNet.Technology.SystemCheck do
  @moduledoc """
  Structure for displaying warnings and errors for
  system configuration
  """

  alias VintageNet.Technology.SystemCheck

  defstruct errors: [],
            warnings: []

  @type t() :: %SystemCheck{
          errors: [iodata()],
          warnings: [iodata()]
        }
end
