defmodule ArkWeb.LockControllerTest do
  use ArkWeb.ConnCase, async: true

  setup %{conn: conn} do
    {authed_conn, user, _api_key, _raw_token} =
      setup_authenticated_conn(conn, username: "lockuser")

    {authed_conn2, user2, _api_key2, _raw_token2} =
      setup_authenticated_conn(conn, username: "otheruser")

    {repo, _membership} = setup_repository_with_member(user, name: "test-repo")

    # user2 is also a member of the same repo
    {:ok, _} = Ark.Repositories.add_member(repo.id, user2.id, :write)

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
      {readonly_conn, user, _key, _token} =
        setup_authenticated_conn(build_conn(), scopes: [:repo_read])

      {:ok, _} = Ark.Repositories.add_member(repo.id, user.id, :write)

      conn = post(readonly_conn, locks_path(repo.id), %{path: "file.fbx"})

      assert json_response(conn, 403)
    end

    test "returns 404 for non-existent repository", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = post(conn, locks_path(fake_id), %{path: "file.fbx"})

      assert %{"error" => "not_found", "reason" => "repository_not_found"} =
               json_response(conn, 404)
    end

    test "returns 403 when user is not a member of the repository", %{conn: conn} do
      {_other_conn, other_user, _key, _token} =
        setup_authenticated_conn(build_conn(), username: "outsider")

      # other_user creates a repo but conn's user is NOT a member
      {other_repo, _} = setup_repository_with_member(other_user, name: "private-repo")

      conn = post(conn, locks_path(other_repo.id), %{path: "file.fbx"})

      assert %{"error" => "forbidden", "reason" => "repository_access_denied"} =
               json_response(conn, 403)
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

    test "returns 403 when deleting another user's lock", %{
      conn: conn,
      conn2: conn2,
      repo: repo
    } do
      create_conn = post(conn, locks_path(repo.id), %{path: "file.fbx"})
      %{"id" => lock_id} = json_response(create_conn, 201)

      conn2 = delete(conn2, lock_path(repo.id, lock_id))
      assert %{"error" => "forbidden", "reason" => "not_lock_owner"} = json_response(conn2, 403)
    end

    test "cannot delete own lock via another repository's endpoint", %{
      conn: conn,
      user: user,
      repo: repo
    } do
      # Create a lock on repo
      create_conn = post(conn, locks_path(repo.id), %{path: "file.fbx"})
      %{"id" => lock_id} = json_response(create_conn, 201)

      # Create another repo where user is also a member
      {other_repo, _} = setup_repository_with_member(user, name: "other-repo")

      # Try to delete repo's lock via other_repo's endpoint — should return 404
      del_conn = delete(conn, lock_path(other_repo.id, lock_id))

      assert %{"error" => "not_found", "reason" => "lock_not_found"} =
               json_response(del_conn, 404)

      # Verify the lock still exists on the original repo
      list_conn = get(conn, locks_path(repo.id))
      assert %{"data" => [%{"id" => ^lock_id}]} = json_response(list_conn, 200)
    end
  end

  describe "POST /api/v1/repositories/:repository_id/locks (validation)" do
    test "returns 400 when path is missing", %{conn: conn, repo: repo} do
      conn = post(conn, locks_path(repo.id), %{})

      assert %{"error" => "bad_request", "reason" => "missing_path"} =
               json_response(conn, 400)
    end

    test "returns 422 with details for absolute path", %{conn: conn, repo: repo} do
      conn = post(conn, locks_path(repo.id), %{path: "/etc/passwd"})

      assert %{"error" => "validation_failed", "details" => %{"path" => [msg]}} =
               json_response(conn, 422)

      assert msg =~ "relative path"
    end

    test "returns 422 with details for path traversal", %{conn: conn, repo: repo} do
      conn = post(conn, locks_path(repo.id), %{path: "models/../../etc/passwd"})

      assert %{"error" => "validation_failed", "details" => %{"path" => [msg]}} =
               json_response(conn, 422)

      assert msg =~ "path traversal"
    end

    test "returns normalized path in response", %{conn: conn, repo: repo} do
      conn = post(conn, locks_path(repo.id), %{path: "./models//hero.fbx"})

      assert %{"locked" => true, "path" => "models/hero.fbx"} = json_response(conn, 201)
    end
  end
end
