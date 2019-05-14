defmodule VintageNet.InterfacesMonitorTest do
  use ExUnit.Case

  alias VintageNet.InterfacesMonitor
  doctest InterfacesMonitor

  test "populates the property table" do
    names = InterfacesMonitor.interfaces()

    for name <- names do
      assert true == VintageNet.get(["interface", name, "present"])
    end
  end
end
