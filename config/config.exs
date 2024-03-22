import Config
config :httpx, auth_extensions: []

config :httpx, :log,
  type: :debug,
  pre: true,
  post: true,
  prefix: "HTTPX: "

config :httpx, default_pool: false
