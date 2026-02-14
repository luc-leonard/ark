defmodule Ark.LockManagerTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.User
  alias Ark.LockManager
  alias Ark.Repositories.Repository
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "user_#{unique_id()}"}))

    {:ok, user2} =
      Repo.insert(User.create_changeset(%User{}, %{username: "user2_#{unique_id()}"}))

    {:ok, repo} =
      Repo.insert(
        Repository.create_changeset(%Repository{}, %{
          name: "repo_#{unique_id()}",
          storage_path: "/data/repos/test",
          owner_id: user.id
        })
      )

    server_name = :"lock_manager_#{unique_id()}"
    {:ok, pid} = LockManager.start_link(name: server_name)
    Sandbox.allow(Repo, self(), pid)

    {:ok, server: pid, name: server_name, user: user, user2: user2, repo: repo}
  end

  defp unique_id, do: System.unique_integer([:positive])

  describe "acquire/4" do
    test "acquires a lock on a free path", ctx do
      assert :ok = LockManager.acquire(ctx.name, ctx.repo.id, "file.fbx", ctx.user.id)
    end

    test "is idempotent for the same user", ctx do
      assert :ok = LockManager.acquire(ctx.name, ctx.repo.id, "file.fbx", ctx.user.id)
      assert :ok = LockManager.acquire(ctx.name, ctx.repo.id, "file.fbx", ctx.user.id)
    end

    test "rejects lock when held by another user", ctx do
      assert :ok = LockManager.acquire(ctx.name, ctx.repo.id, "file.fbx", ctx.user.id)

      assert {:error, :already_locked, holder_id} =
               LockManager.acquire(ctx.name, ctx.repo.id, "file.fbx", ctx.user2.id)

      assert holder_id == ctx.user.id
    end

    test "allows different paths to be locked independently", ctx do
      assert :ok = LockManager.acquire(ctx.name, ctx.repo.id, "a.fbx", ctx.user.id)
      assert :ok = LockManager.acquire(ctx.name, ctx.repo.id, "b.fbx", ctx.user2.id)
    end
  end

  describe "release/3" do
    test "releases an existing lock", ctx do
      :ok = LockManager.acquire(ctx.name, ctx.repo.id, "file.fbx", ctx.user.id)
      assert :ok = LockManager.release(ctx.name, ctx.repo.id, "file.fbx")
      assert [] = LockManager.list_locks(ctx.name, ctx.repo.id)
    end

    test "is safe to call on a non-existent lock", ctx do
      assert :ok = LockManager.release(ctx.name, ctx.repo.id, "nonexistent.fbx")
    end

    test "allows re-acquisition after release", ctx do
      :ok = LockManager.acquire(ctx.name, ctx.repo.id, "file.fbx", ctx.user.id)
      :ok = LockManager.release(ctx.name, ctx.repo.id, "file.fbx")
      assert :ok = LockManager.acquire(ctx.name, ctx.repo.id, "file.fbx", ctx.user2.id)
    end
  end

  describe "list_locks/2" do
    test "returns empty list when no locks", ctx do
      assert [] = LockManager.list_locks(ctx.name, ctx.repo.id)
    end

    test "returns all locks for a repository", ctx do
      :ok = LockManager.acquire(ctx.name, ctx.repo.id, "a.fbx", ctx.user.id)
      :ok = LockManager.acquire(ctx.name, ctx.repo.id, "b.fbx", ctx.user2.id)

      locks = LockManager.list_locks(ctx.name, ctx.repo.id)
      paths = Enum.map(locks, & &1.path) |> Enum.sort()

      assert paths == ["a.fbx", "b.fbx"]
    end

    test "does not return locks from other repositories", ctx do
      {:ok, other_repo} =
        Repo.insert(
          Repository.create_changeset(%Repository{}, %{
            name: "other_#{unique_id()}",
            storage_path: "/data/repos/other",
            owner_id: ctx.user.id
          })
        )

      :ok = LockManager.acquire(ctx.name, ctx.repo.id, "file.fbx", ctx.user.id)
      :ok = LockManager.acquire(ctx.name, other_repo.id, "other.fbx", ctx.user.id)

      locks = LockManager.list_locks(ctx.name, ctx.repo.id)
      assert length(locks) == 1
      assert hd(locks).path == "file.fbx"
    end
  end
end
