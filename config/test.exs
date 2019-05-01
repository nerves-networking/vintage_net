use Mix.Config

# Overrides for unit tests:
#
# * udhcpc_handler: send whatever happens to the log
# * resolvconf: don't update the real resolv.conf
# * persistence_dir: use the current directory
config :vintage_net,
  udhcpc_handler: VintageNetTest.LoggingUdhcpcHandler,
  resolvconf: "/dev/null",
  persistence_dir: "./persistence"
