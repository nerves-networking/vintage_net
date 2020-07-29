# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# Overrides for unit tests:
#
# * udhcpc_handler: capture whatever happens with udhcpc
# * udhcpd_handler: capture whatever happens with udhcpd
# * interface_renamer: capture interfaces that get renamed
# * resolvconf: don't update the real resolv.conf
# * path: limit search for tools to our test harness
# * persistence_dir: use the current directory
# * power_managers: register a manager for test0 so that tests
#      that need to validate power management calls can use it.
#
# NOTE: the power_managers list here exercises common error cases
# that would cause exceptions, but instead print logs so that
# they don't take down an otherwise working system. This leads
# to extra prints when running locally.
config :vintage_net,
  udhcpc_handler: VintageNetTest.CapturingUdhcpcHandler,
  udhcpd_handler: VintageNetTest.CapturingUdhcpdHandler,
  interface_renamer: VintageNetTest.CapturingInterfaceRenamer,
  resolvconf: "/dev/null",
  path: "#{File.cwd!()}/test/fixtures/root/bin",
  persistence_dir: "./test_tmp/persistence",
  power_managers: [
    {VintageNetTest.TestPowerManager, [ifname: "test0", watchdog_timeout: 50]},
    {VintageNetTest.BadPowerManager, [ifname: "bad_power0"]},
    {NonExistentPowerManager, [ifname: "test_does_not_exist_case"]}
  ]
