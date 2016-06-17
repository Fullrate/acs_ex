use Mix.Config

config :logger, level: :info

config :acs_ex, logtopic: "log.acs"
config :acs_ex, eventtopic: "acs.raw"
config :acs_ex, :acs_port, 65432
config :acs_ex,
  crypt_keybase: "31de9f7d766287c7565801f30babbd4f",
  crypt_cookie_salt: "SomeSalt",
  crypt_signed_cookie_salt: "SomeSignedSalt",
  redis_host: 'localhost'

config :kafka_ex, consumer_group: "acs_ex"
config :kafka_ex, brokers: [{"broker1.expert.fullrate.dk", 9092},
                            {"broker2.expert.fullrate.dk", 9092}]

import_config "#{Mix.env}.exs"
