use Mix.Config

config :logger,
  level: :debug,
  backends: [{LoggerFileBackend, :trace_log}]

config :logger, :trace_log,
  path: "test/trace.log",
  level: :debug

config :kafka_ex,
  disable_default_worker: true

config :acs_ex,
  logmode: "file", # file or kafka
  dir: "test/log",
  filename: "acs.log",
  logtopic: "dev.log.acs",
  eventtopic: "dev.acs.raw",
  acs_port: 65432,
  eventfile: "test/event.log",
  session_script: ACS.Session.Script.Vendor
