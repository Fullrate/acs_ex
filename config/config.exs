use Mix.Config

config :logger,
  level: :debug,
  backends: [{LoggerFileBackend, :trace_log}]

config :logger, :trace_log,
  path: "test/trace.log",
  level: :debug

config :acs_ex, :acs_port, 7547
config :acs_ex,
  crypt_keybase: "31de9f7d766287c7565801f30babbd4f",
  crypt_cookie_salt: "SomeSalt",
  crypt_signed_cookie_salt: "SomeSignedSalt"

import_config "#{Mix.env}.exs"
