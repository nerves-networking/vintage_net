use Mix.Config

config :mix_test_watch,
  clear: true,
  tasks: [
    "dialyzer --format dialyxir",
    "test --stale --no-start"
  ]
