defmodule ArkWeb.LockController do
  use ArkWeb, :controller

  def index(conn, %{"repository_id" => repository_id}) do
    locks = Ark.LockManager.list_locks(repository_id)
    json(conn, %{data: locks})
  end

  def create(conn, %{"repository_id" => repository_id, "path" => path, "user_id" => user_id}) do
    case Ark.LockManager.acquire(repository_id, path, user_id) do
      :ok ->
        conn
        |> put_status(:created)
        |> json(%{locked: true, path: path, user_id: user_id})

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

  def delete(conn, %{"repository_id" => repository_id, "path" => path}) do
    Ark.LockManager.release(repository_id, path)
    json(conn, %{unlocked: true, path: path})
  end
end
