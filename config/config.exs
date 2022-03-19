import Config

import_config "#{Mix.env}.exs"

config :logger, :console,
  format: "$time [$level] $metadata $message\n"

