defmodule Ark.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  use Boundary, top_level?: true, deps: [Ark.Storage, ArkWeb]

  @impl true
  def start(_type, _args) do
    children = [
      ArkWeb.Telemetry,
      {Task, &Ark.Storage.startup_cleanup/0},
      Ark.Repo,
      {DNSCluster, query: Application.get_env(:ark, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Ark.PubSub},
      # Start to serve requests, typically the last entry
      ArkWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ark.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ArkWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
