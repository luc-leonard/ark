defmodule ArkWeb.LockController do
  use ArkWeb, :controller

  plug ArkWeb.Plugs.LoadRepository
  plug ArkWeb.Plugs.RequireScope, :lock when action in [:create, :delete]

  def index(conn, _params) do
    repository = conn.assigns.repository

    locks =
      Ark.LockManager.list_locks(repository.id)
      |> Enum.map(&%{id: &1.id, path: &1.path, user_id: &1.user_id, locked_at: &1.inserted_at})

    json(conn, %{data: locks})
  end

  def create(conn, %{"path" => path}) do
    user = conn.assigns.current_user
    repository = conn.assigns.repository

    case Ark.LockManager.acquire(repository.id, path, user.id) do
      {:ok, lock} ->
        conn
        |> put_status(:created)
        |> json(%{locked: true, id: lock.id, path: path, user_id: user.id})

      {:error, :already_locked, holder_id} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "already_locked", holder_id: holder_id})

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

    case Ark.LockManager.get_lock(id) do
      nil ->
        json(conn, %{unlocked: true, id: id})

      %{repository_id: repo_id} when repo_id != repository.id ->
        json(conn, %{unlocked: true, id: id})

      %{user_id: user_id} when user_id != user.id ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden", reason: "not_lock_owner"})

      _lock ->
        Ark.LockManager.release(id)
        json(conn, %{unlocked: true, id: id})
    end
  end
end
