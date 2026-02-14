defmodule ArkWeb.Plugs.RequireScope do
  @moduledoc """
  Plug that verifies the current API key has a required scope.

  Must be used after `ArkWeb.Plugs.ApiAuth` in the pipeline.

  ## Usage in a controller

      plug ArkWeb.Plugs.RequireScope, :lock when action in [:create, :delete]
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @behaviour Plug

  @impl true
  def init(scope) when is_atom(scope), do: scope

  @impl true
  def call(conn, required_scope) do
    api_key = conn.assigns[:current_api_key]

    if api_key && Ark.Accounts.has_scope?(api_key, required_scope) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "forbidden", reason: "missing_scope", required: required_scope})
      |> halt()
    end
  end
end
