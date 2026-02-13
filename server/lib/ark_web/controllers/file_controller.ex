defmodule ArkWeb.FileController do
  use ArkWeb, :controller

  def index(conn, _params) do
    json(conn, %{data: []})
  end

  def show(conn, %{"id" => _id}) do
    json(conn, %{data: %{}})
  end

  def create(conn, _params) do
    conn
    |> put_status(:created)
    |> json(%{data: %{}})
  end
end
