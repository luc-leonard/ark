# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ark,
  ecto_repos: [Ark.Repo],
  generators: [timestamp_type: :utc_datetime]

config :ark, Ark.Storage, backend: Ark.Storage.Local

# Configure the endpoint
config :ark, ArkWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: ArkWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Ark.PubSub,
  live_view: [signing_salt: "XzGy9Mne"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
