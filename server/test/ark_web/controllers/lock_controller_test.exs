defmodule ArkWeb.LockControllerTest do
  use ArkWeb.ConnCase, async: true

  alias Ark.Repo
  alias Ark.Repositories.Repository

  setup %{conn: conn} do
    {authed_conn, user, _api_key, _raw_token} =
      setup_authenticated_conn(conn, username: "lockuser")

    {authed_conn2, user2, _api_key2, _raw_token2} =
      setup_authenticated_conn(conn, username: "otheruser")

    {:ok, repo} =
      Repo.insert(
        %Repository{owner_id: user.id}
        |> Repository.create_changeset(%{
          name: "test-repo",
          storage_path: "/data/repos/test"
        })
      )

    {:ok, conn: authed_conn, conn2: authed_conn2, user: user, user2: user2, repo: repo}
  end

  defp locks_path(repo_id), do: "/api/v1/repositories/#{repo_id}/locks"
  defp lock_path(repo_id, lock_id), do: "/api/v1/repositories/#{repo_id}/locks/#{lock_id}"

  describe "POST /api/v1/repositories/:repository_id/locks" do
    test "creates a lock", %{conn: conn, user: user, repo: repo} do
      conn = post(conn, locks_path(repo.id), %{path: "file.fbx"})

      assert %{"locked" => true, "id" => _id, "path" => "file.fbx", "user_id" => uid} =
               json_response(conn, 201)

      assert uid == user.id
    end

    test "returns 409 when already locked by another user", %{
      conn: conn,
      conn2: conn2,
      repo: repo
    } do
      post(conn, locks_path(repo.id), %{path: "file.fbx"})

      conn2 = post(conn2, locks_path(repo.id), %{path: "file.fbx"})

      assert %{"error" => "already_locked", "holder_id" => _} = json_response(conn2, 409)
    end

    test "returns 401 without auth header", %{repo: repo} do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post(locks_path(repo.id), %{path: "file.fbx"})

      assert json_response(conn, 401)
    end

    test "returns 403 without lock scope", %{repo: repo} do
      {readonly_conn, _user, _key, _token} =
        setup_authenticated_conn(build_conn(), scopes: [:repo_read])

      conn = post(readonly_conn, locks_path(repo.id), %{path: "file.fbx"})

      assert json_response(conn, 403)
    end
  end

  describe "GET /api/v1/repositories/:repository_id/locks" do
    test "returns empty list when no locks", %{conn: conn, repo: repo} do
      conn = get(conn, locks_path(repo.id))
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns locks for the repository", %{conn: conn, user: user, repo: repo} do
      post(conn, locks_path(repo.id), %{path: "a.fbx"})

      conn = get(conn, locks_path(repo.id))
      assert %{"data" => [lock]} = json_response(conn, 200)
      assert lock["path"] == "a.fbx"
      assert lock["user_id"] == user.id
      assert lock["locked_at"]
    end
  end

  describe "DELETE /api/v1/repositories/:repository_id/locks/:id" do
    test "releases a lock", %{conn: conn, repo: repo} do
      create_conn = post(conn, locks_path(repo.id), %{path: "file.fbx"})

      %{"id" => lock_id} = json_response(create_conn, 201)

      conn = delete(conn, lock_path(repo.id, lock_id))
      assert %{"unlocked" => true, "id" => ^lock_id} = json_response(conn, 200)
    end
  end
end
