use Mix.Config

config :vintage_net, udhcpc_handler: VintageNetTest.LoggingUdhcpcHandler, resolvconf: "/dev/null"
