# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :mix_test_watch,
  clear: true,
  tasks: [
    "dialyzer --format dialyxir",
    "test --stale --no-start"
  ]

# Overrides for unit tests:
#
# * udhcpc_handler: send whatever happens to the log
# * resolvconf: don't update the real resolv.conf
# * persistence_dir: use the current directory
config :vintage_net,
  udhcpc_handler: VintageNetTest.LoggingUdhcpcHandler,
  resolvconf: "/dev/null",
  persistence_dir: "./persistence",
  bin_ip: "false"
