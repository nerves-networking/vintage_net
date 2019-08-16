defmodule VintageNet.IP.DhcpdConfigTest do
  use ExUnit.Case

  alias VintageNet.IP.DhcpdConfig

  test "dhcpd normalizes" do
    config = %{
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

    normalized_config = %{
      dhcpd: %{
        auto_time: 60,
        conflict_time: 200,
        decline_time: 100,
        end: {192, 168, 1, 100},
        max_leases: 98,
        min_lease: 60,
        offer_time: 300,
        start: {192, 168, 1, 2},
        static_leases: [
          {"00:60:08:11:CE:4E", {192, 168, 1, 55}},
          {"00:60:08:11:CE:3E", {192, 168, 1, 56}}
        ]
      }
    }

    assert normalized_config == DhcpdConfig.normalize(config)
  end

  test "dhcpd converts configs" do
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

    initial_raw_config = %VintageNet.Interface.RawConfig{
      ifname: "eth0",
      source_config: input,
      type: UnitTest
    }

    opts = [tmpdir: "tmpdir", bin_udhcpd: "udhcpd"]

    result = DhcpdConfig.add_config(initial_raw_config, input, opts)

    expected = %VintageNet.Interface.RawConfig{
      child_specs: [
        %{
          id: :udhcpd,
          restart: :permanent,
          shutdown: 500,
          start:
            {MuonTrap.Daemon, :start_link,
             [
               "udhcpd",
               ["-f", "tmpdir/udhcpd.conf.eth0"],
               [stderr_to_stdout: true, log_output: :debug]
             ]},
          type: :worker
        }
      ],
      files: [
        {"tmpdir/udhcpd.conf.eth0",
         """
         interface eth0
         pidfile tmpdir/udhcpd.eth0.pid
         lease_file tmpdir/udhcpd.eth0.leases
         notify_file #{Application.app_dir(:vintage_net)}/priv/udhcpd_handler

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

         """}
      ],
      ifname: "eth0",
      source_config: input,
      type: UnitTest
    }

    assert expected == result
  end
end
