defmodule VintageNet.IP.ConfigToUdhcpdTest do
  use ExUnit.Case
  alias VintageNet.IP.ConfigToUdhcpd

  test "dhcp server config" do
    tmp_dir = "test_tmp"

    input = %{
      dhcpd: %{
        start: "192.168.1.2",
        end: "192.168.1.100",
        max_leases: 98,
        decline_time: 100,
        conflict_time: 200,
        offer_time: 300,
        min_lease: 60,
        auto_time: 60,
        static_leases: [
          {"00:60:08:11:CE:4E", "192.168.1.55"},
          {"00:60:08:11:CE:3E", "192.168.1.56"}
        ]
      }
    }

    output = ConfigToUdhcpd.config_to_udhcpd_contents("eth0", input, tmp_dir)

    assert output =~ """
           auto_time 60
           conflict_time 200
           decline_time 100
           end 192.168.1.100
           max_leases 98
           min_lease 60
           offer_time 300
           start 192.168.1.2
           static_lease 00:60:08:11:CE:4E 192.168.1.55
           static_lease 00:60:08:11:CE:3E 192.168.1.56
           """
  end
end
