defmodule VintageNet.Template.Ethernet do
  @moduledoc """
  Settings templates for wired Ethernet connections
  """

  def simple_dhcp() do
    %{ipv4: %{method: :dhcp}}
  end
end
