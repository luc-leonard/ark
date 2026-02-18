defmodule ArkWeb.Plugs.ApiAuthTest do
  use ArkWeb.ConnCase, async: true

  alias Ark.Accounts
  alias Ark.Accounts.{ApiKey, User}
  alias Ark.Repo
  alias ArkWeb.Plugs.ApiAuth

  describe "call/2" do
    test "assigns current_user and current_api_key for valid token", %{conn: conn} do
      {authed_conn, user, _api_key, _raw_token} = setup_authenticated_conn(conn)

      result = ApiAuth.call(authed_conn, [])

      refute result.halted
      assert result.assigns.current_user.id == user.id
      assert result.assigns.current_api_key.user_id == user.id
    end

    test "returns 401 when no authorization header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> ApiAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body)["reason"] == "missing_token"
    end

    test "returns 401 for invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer ark_invalidtoken")
        |> ApiAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body)["reason"] == "invalid_token"
    end

    test "returns 401 for expired token", %{conn: conn} do
      {:ok, user} =
        Repo.insert(User.create_changeset(%User{}, %{username: "expired_user"}))

      {:ok, _api_key, raw_token} =
        Accounts.create_api_key(user, %{
          name: "expired-key",
          scopes: [:repo_read],
          expires_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> raw_token)
        |> ApiAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body)["reason"] == "token_expired"
    end

    test "returns 401 for revoked token", %{conn: conn} do
      {:ok, user} =
        Repo.insert(User.create_changeset(%User{}, %{username: "revoked_user"}))

      {:ok, api_key, raw_token} =
        Accounts.create_api_key(user, %{
          name: "revoked-key",
          scopes: [:repo_read],
          expires_at: DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)
        })

      {:ok, _} = api_key |> ApiKey.revoke_changeset() |> Repo.update()

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> raw_token)
        |> ApiAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body)["reason"] == "token_revoked"
    end
  end
end
