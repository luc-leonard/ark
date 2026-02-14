defmodule ArkWeb.LockControllerTest do
  use ArkWeb.ConnCase, async: false

  alias Ark.Accounts.User
  alias Ark.Repo
  alias Ark.Repositories.Repository
  alias Ecto.Adapters.SQL.Sandbox

  setup %{conn: conn} do
    Sandbox.allow(Repo, self(), Process.whereis(Ark.LockManager))

    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "lockuser"}))
    {:ok, user2} = Repo.insert(User.create_changeset(%User{}, %{username: "otheruser"}))

    {:ok, repo} =
      Repo.insert(
        Repository.create_changeset(%Repository{}, %{
          name: "test-repo",
          storage_path: "/data/repos/test",
          owner_id: user.id
        })
      )

    {:ok,
     conn: put_req_header(conn, "content-type", "application/json"),
     user: user,
     user2: user2,
     repo: repo}
  end

  describe "POST /api/v1/locks" do
    test "creates a lock", %{conn: conn, user: user, repo: repo} do
      conn =
        post(conn, "/api/v1/locks", %{
          repository_id: repo.id,
          path: "file.fbx",
          user_id: user.id
        })

      assert %{"locked" => true, "id" => _id, "path" => "file.fbx"} = json_response(conn, 201)
    end

    test "returns 409 when already locked by another user", %{
      conn: conn,
      user: user,
      user2: user2,
      repo: repo
    } do
      post(conn, "/api/v1/locks", %{repository_id: repo.id, path: "file.fbx", user_id: user.id})

      conn =
        post(conn, "/api/v1/locks", %{
          repository_id: repo.id,
          path: "file.fbx",
          user_id: user2.id
        })

      assert %{"error" => "already_locked", "holder_id" => _} = json_response(conn, 409)
    end
  end

  describe "GET /api/v1/locks" do
    test "returns empty list when no locks", %{conn: conn, repo: repo} do
      conn = get(conn, "/api/v1/locks", %{repository_id: repo.id})
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns locks for the repository", %{conn: conn, user: user, repo: repo} do
      post(conn, "/api/v1/locks", %{repository_id: repo.id, path: "a.fbx", user_id: user.id})

      conn = get(conn, "/api/v1/locks", %{repository_id: repo.id})
      assert %{"data" => [lock]} = json_response(conn, 200)
      assert lock["path"] == "a.fbx"
      assert lock["user_id"] == user.id
      assert lock["locked_at"]
    end
  end

  describe "DELETE /api/v1/locks/:id" do
    test "releases a lock", %{conn: conn, user: user, repo: repo} do
      create_conn =
        post(conn, "/api/v1/locks", %{
          repository_id: repo.id,
          path: "file.fbx",
          user_id: user.id
        })

      %{"id" => lock_id} = json_response(create_conn, 201)

      conn = delete(conn, "/api/v1/locks/#{lock_id}")
      assert %{"unlocked" => true, "id" => ^lock_id} = json_response(conn, 200)
    end
  end
end
