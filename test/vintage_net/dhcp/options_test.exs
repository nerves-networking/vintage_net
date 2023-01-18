defmodule VintageNet.DHCP.OptionsTest do
  use ExUnit.Case, async: true

  alias VintageNet.DHCP.Options

  test "translate typical options correctly" do
    info = %{
      "dns" => "192.168.1.149 1.1.1.1 9.9.9.9",
      "domain" => "localdomain",
      "interface" => "eth0",
      "ip" => "192.168.1.245",
      "lease" => "86400",
      "mask" => "24",
      "ntpsrv" => "192.168.1.149",
      "opt53" => "05",
      "opt58" => "0000a8c0",
      "opt59" => "00012750",
      "router" => "192.168.1.1",
      "serverid" => "192.168.1.1",
      "subnet" => "255.255.255.0"
    }

    expected_options = %{
      dns: [{192, 168, 1, 149}, {1, 1, 1, 1}, {9, 9, 9, 9}],
      domain: "localdomain",
      ip: {192, 168, 1, 245},
      lease: 86400,
      mask: 24,
      ntpsrv: [{192, 168, 1, 149}],
      router: [{192, 168, 1, 1}],
      rebind_time: 75600,
      renewal_time: 43200,
      serverid: {192, 168, 1, 1},
      subnet: {255, 255, 255, 0}
    }

    assert expected_options == Options.udhcpc_to_options(info)
  end
end
