defmodule VintageNet.IP.DnsdConfigTest do
  use ExUnit.Case

  alias VintageNet.IP.DnsdConfig

  test "dnsd normalizes" do
    config = %{
      ipv4: %{method: :static, address: {192, 168, 1, 1}, prefix_length: 24},
      dnsd: %{
        records: [
          {"sample.com", "192.168.1.4"},
          {"another.com", "192.168.1.5"}
        ]
      }
    }

    normalized_config = %{
      ipv4: %{method: :static, address: {192, 168, 1, 1}, prefix_length: 24},
      dnsd: %{
        records: [
          {"sample.com", {192, 168, 1, 4}},
          {"another.com", {192, 168, 1, 5}}
        ]
      }
    }

    assert normalized_config == DnsdConfig.normalize(config)
  end

  test "Dnsd converts configs" do
    input = %{
      ipv4: %{method: :static, address: {192, 168, 1, 1}, prefix_length: 24},
      dnsd: %{
        records: [
          {"sample.com", "192.168.1.4"},
          {"another.com", "192.168.1.5"}
        ]
      }
    }

    initial_raw_config = %VintageNet.Interface.RawConfig{
      ifname: "eth0",
      source_config: input,
      type: UnitTest,
      required_ifnames: ["eth0"]
    }

    opts = [tmpdir: "tmpdir", bin_dnsd: "dnsd"]

    result = DnsdConfig.add_config(initial_raw_config, input, opts)

    expected = %VintageNet.Interface.RawConfig{
      child_specs: [
        %{
          id: :dnsd,
          restart: :permanent,
          shutdown: 500,
          start:
            {MuonTrap.Daemon, :start_link,
             [
               "dnsd",
               ["-c", "tmpdir/dnsd.conf.eth0", "-i", "192.168.1.1"],
               [stderr_to_stdout: true, log_output: :debug]
             ]},
          type: :worker
        }
      ],
      files: [
        {"tmpdir/dnsd.conf.eth0",
         """
         sample.com 192.168.1.4
         another.com 192.168.1.5
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
