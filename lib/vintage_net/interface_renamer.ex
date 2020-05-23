defmodule VintageNet.InterfaceRenamer do
  @moduledoc """
  Wrapper around the `ip` command for renaming interfaces
  """

  @callback rename_interface(VintageNet.ifname(), VintageNet.ifname()) ::
              :ok | {:error, String.t()}

  @doc "Renames an interface"
  def rename(ifname, rename_to) do
    renamer().rename_interface(ifname, rename_to)
  end

  def renamer do
    case Application.get_env(:vintage_net, :interface_renamer) do
      nil -> InterfaceRenamer.IP
      module when is_atom(module) -> module
    end
  end
end
