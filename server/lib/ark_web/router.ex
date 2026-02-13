defmodule ArkWeb.Router do
  use ArkWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check — outside API namespace for K8s probes
  get "/health", ArkWeb.HealthController, :index

  scope "/api/v1", ArkWeb do
    pipe_through :api

    resources "/files", FileController, only: [:index, :show, :create]

    post "/locks", LockController, :create
    delete "/locks/:path", LockController, :delete
    get "/locks", LockController, :index
  end
end
