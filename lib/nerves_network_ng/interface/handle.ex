defmodule Nerves.NetworkNG.Interface.Handle do
  alias Nerves.NetworkNG.Interface

  @callback handle_down(Interface.t()) :: :ok

  @callback handle_up(Interface.t()) :: :ok

  @callback handle_info(Interface.t()) :: :ok
end
