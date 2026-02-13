defmodule ArkWeb.LockController do
  use ArkWeb, :controller

  def index(conn, _params) do
    locks = Ark.LockManager.list_locks()
    json(conn, %{data: locks})
  end

  def create(conn, %{"path" => path, "user" => user}) do
    case Ark.LockManager.acquire(path, user) do
      :ok ->
        conn
        |> put_status(:created)
        |> json(%{locked: true, path: path, user: user})

      {:error, :already_locked, holder} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "already_locked", holder: holder})
    end
  end

  def delete(conn, %{"path" => path}) do
    Ark.LockManager.release(path)
    json(conn, %{unlocked: true, path: path})
  end
end
