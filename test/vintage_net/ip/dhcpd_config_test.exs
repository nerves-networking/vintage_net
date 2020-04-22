defmodule VintageNet.IP.DhcpdConfigTest do
  use ExUnit.Case

  alias VintageNet.IP.DhcpdConfig

  test "dhcpd has defaults" do
    default_config = %{
      dhcpd: %{
        end: {192, 168, 0, 254},
        start: {192, 168, 0, 20}
      }
    }

    assert default_config == DhcpdConfig.normalize(%{dhcpd: %{}})
  end

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
        ],
        options: %{
          :dns => ["192.168.1.1", "1.1.1.1"],
          :mtu => 9216,
          :serverid => {192, 168, 1, 1},
          :hostname => "marshmallow",
          0x08 => "01020304"
        }
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
        ],
        options: %{
          :dns => [{192, 168, 1, 1}, {1, 1, 1, 1}],
          :hostname => "marshmallow",
          :mtu => 9216,
          :serverid => {192, 168, 1, 1},
          8 => "01020304"
        }
      }
    }

    assert normalized_config == DhcpdConfig.normalize(config)
  end

  test "normalize fixes item passed instead of list" do
    # Pass an IP address rather than a list for the DNS option
    config = %{
      dhcpd: %{
        options: %{
          dns: "192.168.1.1"
        }
      }
    }

    expected = %{
      dhcpd: %{
        end: {192, 168, 0, 254},
        start: {192, 168, 0, 20},
        options: %{
          dns: [{192, 168, 1, 1}]
        }
      }
    }

    assert expected == DhcpdConfig.normalize(config)
  end

  test "bad options give understandable exceptions" do
    # Pass an IP address rather than a list for the DNS option
    config = %{
      dhcpd: %{
        options: %{
          bad_option: "192.168.1.1"
        }
      }
    }

    assert_raise ArgumentError, fn -> DhcpdConfig.normalize(config) end
  end

  test "dhcpd converts configs" do
    input =
      %{
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
          ],
          options: %{
            :dns => ["192.168.1.1", "1.1.1.1"],
            :mtu => 9216,
            :serverid => {192, 168, 1, 1},
            :hostname => "marshmallow",
            :domain => "mylan.com",
            :router => "192.168.1.1",
            :search => ["mylan.com", "another-lan.com"],
            :subnet => "255.255.255.0",
            0x08 => "01020304"
          }
        }
      }
      |> DhcpdConfig.normalize()

    initial_raw_config = %VintageNet.Interface.RawConfig{
      ifname: "eth0",
      source_config: input,
      type: UnitTest,
      required_ifnames: ["eth0"]
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
         opt 8 01020304
         opt dns 192.168.1.1 1.1.1.1
         opt domain mylan.com
         opt hostname marshmallow
         opt mtu 9216
         opt router 192.168.1.1
         opt search mylan.com another-lan.com
         opt serverid 192.168.1.1
         opt subnet 255.255.255.0
         start 192.168.1.2
         static_lease 00:60:08:11:CE:4E 192.168.1.55
         static_lease 00:60:08:11:CE:3E 192.168.1.56

         """}
      ],
      ifname: "eth0",
      source_config: input,
      type: UnitTest,
      required_ifnames: ["eth0"]
    }

    assert expected == result
  end
end
