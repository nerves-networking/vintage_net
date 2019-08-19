defmodule VintageNet.Technology.GadgetTest do
  use ExUnit.Case
  alias VintageNet.Interface.RawConfig
  alias VintageNet.Technology.Gadget

  import VintageNetTest.Utils

  test "normalization simplifies configuration" do
    input = %{type: VintageNet.Technology.Gadget, random_field: 42}

    assert Gadget.normalize(input) == %{type: VintageNet.Technology.Gadget, gadget: %{}}
  end

  test "normalization preserves hostname override" do
    input = %{type: VintageNet.Technology.Gadget, gadget: %{hostname: "my_host"}}

    assert Gadget.normalize(input) == %{
             type: VintageNet.Technology.Gadget,
             gadget: %{hostname: "my_host"}
           }
  end

  test "create a gadget configuration" do
    input = %{
      type: VintageNet.Technology.Gadget,
      gadget: %{hostname: "test_hostname"}
    }

    output = Gadget.to_raw_config("usb0", input, default_opts())

    expected = %RawConfig{
      ifname: "usb0",
      type: VintageNet.Technology.Gadget,
      source_config: input,
      child_specs: [
        %{id: {OneDHCPD, "usb0"}, start: {OneDHCPD, :start_server, ["usb0"]}},
        {VintageNet.Interface.LANConnectivityChecker, "usb0"}
      ],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "usb0", "label", "usb0"]},
        {:run, "ip", ["link", "set", "usb0", "down"]}
      ],
      files: [],
      up_cmd_millis: 5000,
      up_cmds: [
        {:run, "ip", ["addr", "add", "172.31.246.65/30", "dev", "usb0", "label", "usb0"]},
        {:run, "ip", ["link", "set", "usb0", "up"]}
      ]
    }

    assert expected == output
  end
end
