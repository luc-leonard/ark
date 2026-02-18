defmodule Ark.Repo do
  use Ecto.Repo,
    otp_app: :ark,
    adapter: Ecto.Adapters.Postgres

  use Boundary, deps: [], exports: []
end
