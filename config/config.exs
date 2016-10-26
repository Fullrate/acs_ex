use Mix.Config

config :acs_ex,
  acs_port: 7548,
  acs_ip: {0, 0, 0, 0, 0, 0, 0, 0}

import_config "#{Mix.env}.exs"
