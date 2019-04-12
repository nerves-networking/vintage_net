use Mix.Config

config :mix_test_watch,
  clear: true,
  tasks: [
    "dialyzer --format dialyxir",
    "test --stale --no-start"
  ]

# Examples
# config :vintage_net,
# config: [
# {"eth0", %{type: :ethernet, ipv4: %{method: :dhcp}}},
# {"wlan0", %{type: :wifi}}
# ]
