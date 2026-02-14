defmodule ArkWeb.Plugs.LoadRepository do
  @moduledoc """
  Plug that loads a repository and verifies the current user has access.

  Extracts `repository_id` from conn params, loads the repository,
  and checks membership. Assigns `repository` and `membership` to
  the conn on success. Returns 404 or 403 JSON on failure.

  Must be used after `ArkWeb.Plugs.ApiAuth` in the pipeline.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{params: %{"repository_id" => repository_id}} = conn, _opts) do
    user = conn.assigns.current_user

    case Ark.Repositories.get_repository(repository_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", reason: "repository_not_found"})
        |> halt()

      repository ->
        case Ark.Repositories.get_member(repository.id, user.id) do
          nil ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: "forbidden", reason: "repository_access_denied"})
            |> halt()

          membership ->
            conn
            |> assign(:repository, repository)
            |> assign(:membership, membership)
        end
    end
  end
end
