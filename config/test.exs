use Mix.Config

config :logger,
  level: :error

config :kafka_ex,
  disable_default_worker: true

config :acs_ex,
  acs_port: 65432
