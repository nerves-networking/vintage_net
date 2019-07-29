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
# * udhcpc_handler: capture whatever happens with udhcpc
# * udhcpd_handler: capture whatever happens with udhcpd
# * resolvconf: don't update the real resolv.conf
# * persistence_dir: use the current directory
# * bin_ip: just fail if anything calls ip rather that run it
config :vintage_net,
  udhcpc_handler: VintageNetTest.CapturingUdhcpcHandler,
  udhcpd_handler: VintageNetTest.CapturingUdhcpdHandler,
  resolvconf: "/dev/null",
  persistence_dir: "./test_tmp/persistence",
  bin_ip: "false"
