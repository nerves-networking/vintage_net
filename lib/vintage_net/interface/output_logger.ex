defmodule VintageNet.Interface.OutputLogger do
  @moduledoc false

  require Logger

  defstruct prefix: ""
  @type t :: %__MODULE__{prefix: String.t()}

  @spec new(String.t()) :: t()
  def new(prefix), do: %__MODULE__{prefix: prefix}

  defimpl Collectable do
    @spec into(Collectable.t()) ::
            {initial_acc :: term(),
             collector :: (term(), Collectable.command() -> Collectable.t() | term())}
    def into(%VintageNet.Interface.OutputLogger{} = logger) do
      {logger, &collector/2}
    end

    defp collector(%VintageNet.Interface.OutputLogger{prefix: prefix} = logger, {:cont, text}) do
      text
      |> String.split("\n", trim: true)
      |> Enum.each(&Logger.debug(prefix <> &1))

      logger
    end

    defp collector(logger, :done), do: logger
    defp collector(_logger, :halt), do: :ok
  end
end
