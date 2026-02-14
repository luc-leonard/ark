defmodule ArkWeb.LockControllerTest do
  use ArkWeb.ConnCase, async: false

  alias Ark.Repo
  alias Ark.Repositories.Repository
  alias Ecto.Adapters.SQL.Sandbox

  setup %{conn: conn} do
    Sandbox.allow(Repo, self(), Process.whereis(Ark.LockManager))

    {authed_conn, user, _api_key, _raw_token} =
      setup_authenticated_conn(conn, username: "lockuser")

    {authed_conn2, user2, _api_key2, _raw_token2} =
      setup_authenticated_conn(conn, username: "otheruser")

    {:ok, repo} =
      Repo.insert(
        Repository.create_changeset(%Repository{}, %{
          name: "test-repo",
          storage_path: "/data/repos/test",
          owner_id: user.id
        })
      )

    {:ok, conn: authed_conn, conn2: authed_conn2, user: user, user2: user2, repo: repo}
  end

  describe "POST /api/v1/locks" do
    test "creates a lock", %{conn: conn, user: user, repo: repo} do
      conn =
        post(conn, "/api/v1/locks", %{
          repository_id: repo.id,
          path: "file.fbx"
        })

      assert %{"locked" => true, "id" => _id, "path" => "file.fbx", "user_id" => uid} =
               json_response(conn, 201)

      assert uid == user.id
    end

    test "returns 409 when already locked by another user", %{
      conn: conn,
      conn2: conn2,
      repo: repo
    } do
      post(conn, "/api/v1/locks", %{repository_id: repo.id, path: "file.fbx"})

      conn2 =
        post(conn2, "/api/v1/locks", %{
          repository_id: repo.id,
          path: "file.fbx"
        })

      assert %{"error" => "already_locked", "holder_id" => _} = json_response(conn2, 409)
    end

    test "returns 401 without auth header", %{repo: repo} do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/locks", %{repository_id: repo.id, path: "file.fbx"})

      assert json_response(conn, 401)
    end

    test "returns 403 without lock scope", %{conn: _conn, repo: repo} do
      {readonly_conn, _user, _key, _token} =
        setup_authenticated_conn(build_conn(), scopes: [:repo_read])

      conn =
        post(readonly_conn, "/api/v1/locks", %{repository_id: repo.id, path: "file.fbx"})

      assert json_response(conn, 403)
    end
  end

  describe "GET /api/v1/locks" do
    test "returns empty list when no locks", %{conn: conn, repo: repo} do
      conn = get(conn, "/api/v1/locks", %{repository_id: repo.id})
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns locks for the repository", %{conn: conn, user: user, repo: repo} do
      post(conn, "/api/v1/locks", %{repository_id: repo.id, path: "a.fbx"})

      conn = get(conn, "/api/v1/locks", %{repository_id: repo.id})
      assert %{"data" => [lock]} = json_response(conn, 200)
      assert lock["path"] == "a.fbx"
      assert lock["user_id"] == user.id
      assert lock["locked_at"]
    end
  end

  describe "DELETE /api/v1/locks/:id" do
    test "releases a lock", %{conn: conn, repo: repo} do
      create_conn =
        post(conn, "/api/v1/locks", %{
          repository_id: repo.id,
          path: "file.fbx"
        })

      %{"id" => lock_id} = json_response(create_conn, 201)

      conn = delete(conn, "/api/v1/locks/#{lock_id}")
      assert %{"unlocked" => true, "id" => ^lock_id} = json_response(conn, 200)
    end
  end
end
