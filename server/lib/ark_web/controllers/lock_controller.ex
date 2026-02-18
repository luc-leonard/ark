defmodule ArkWeb.LockController do
  use ArkWeb, :controller

  plug ArkWeb.Plugs.LoadRepository
  plug ArkWeb.Plugs.RequireScope, :lock when action in [:create, :delete]

  def index(conn, _params) do
    repository = conn.assigns.repository

    locks =
      Ark.Locking.list_locks(repository.id)
      |> Enum.map(&%{id: &1.id, path: &1.path, user_id: &1.user_id, locked_at: &1.inserted_at})

    json(conn, %{data: locks})
  end

  def create(conn, %{"path" => path}) do
    user = conn.assigns.current_user
    repository = conn.assigns.repository

    case Ark.Locking.acquire(repository.id, path, user.id) do
      {:ok, lock} ->
        conn
        |> put_status(:created)
        |> json(%{locked: true, id: lock.id, path: lock.path, user_id: user.id})

      {:error, :already_locked, holder_id} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "already_locked", holder_id: holder_id})

      {:error, :validation, changeset} ->
        errors = format_changeset_errors(changeset)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_failed", details: errors})

      {:error, :insert_failed} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "lock_failed"})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", reason: "missing_path"})
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    repository = conn.assigns.repository

    case Ark.Locking.get_lock(id) do
      nil ->
        json(conn, %{unlocked: true, id: id})

      %{repository_id: repo_id} when repo_id != repository.id ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", reason: "lock_not_found"})

      %{user_id: user_id} when user_id != user.id ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden", reason: "not_lock_owner"})

      _lock ->
        case Ark.Locking.release(id) do
          :ok ->
            json(conn, %{unlocked: true, id: id})

          {:error, :release_failed} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "release_failed"})
        end
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
