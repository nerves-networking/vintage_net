defmodule VintageNet.Interface.Registry do
  def via_name(_module, interface_pid) when is_pid(interface_pid), do: interface_pid

  def via_name(module, interface_name) do
    {:via, Registry, reg_name(module, interface_name)}
  end

  def reg_name(module, interface_name) do
    {__MODULE__, module, interface_name}
  end
end
