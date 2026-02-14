defmodule Ark.LockManagerTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.User
  alias Ark.LockManager
  alias Ark.Repositories.Repository

  setup do
    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "user_#{unique_id()}"}))

    {:ok, user2} =
      Repo.insert(User.create_changeset(%User{}, %{username: "user2_#{unique_id()}"}))

    {:ok, repo} =
      Repo.insert(
        %Repository{owner_id: user.id}
        |> Repository.create_changeset(%{
          name: "repo_#{unique_id()}",
          storage_path: "/data/repos/test"
        })
      )

    {:ok, user: user, user2: user2, repo: repo}
  end

  defp unique_id, do: System.unique_integer([:positive])

  describe "acquire/3" do
    test "acquires a lock on a free path", ctx do
      assert {:ok, lock} = LockManager.acquire(ctx.repo.id, "file.fbx", ctx.user.id)
      assert lock.path == "file.fbx"
      assert lock.user_id == ctx.user.id
    end

    test "is idempotent for the same user", ctx do
      assert {:ok, lock1} = LockManager.acquire(ctx.repo.id, "file.fbx", ctx.user.id)
      assert {:ok, lock2} = LockManager.acquire(ctx.repo.id, "file.fbx", ctx.user.id)
      assert lock1.id == lock2.id
    end

    test "rejects lock when held by another user", ctx do
      assert {:ok, _lock} = LockManager.acquire(ctx.repo.id, "file.fbx", ctx.user.id)

      assert {:error, :already_locked, holder_id} =
               LockManager.acquire(ctx.repo.id, "file.fbx", ctx.user2.id)

      assert holder_id == ctx.user.id
    end

    test "allows different paths to be locked independently", ctx do
      assert {:ok, _} = LockManager.acquire(ctx.repo.id, "a.fbx", ctx.user.id)
      assert {:ok, _} = LockManager.acquire(ctx.repo.id, "b.fbx", ctx.user2.id)
    end
  end

  describe "release/1" do
    test "releases an existing lock", ctx do
      {:ok, lock} = LockManager.acquire(ctx.repo.id, "file.fbx", ctx.user.id)
      assert :ok = LockManager.release(lock.id)
      assert [] = LockManager.list_locks(ctx.repo.id)
    end

    test "is safe to call on a non-existent lock" do
      assert :ok = LockManager.release(Ecto.UUID.generate())
    end

    test "allows re-acquisition after release", ctx do
      {:ok, lock} = LockManager.acquire(ctx.repo.id, "file.fbx", ctx.user.id)
      :ok = LockManager.release(lock.id)
      assert {:ok, _} = LockManager.acquire(ctx.repo.id, "file.fbx", ctx.user2.id)
    end
  end

  describe "list_locks/1" do
    test "returns empty list when no locks", ctx do
      assert [] = LockManager.list_locks(ctx.repo.id)
    end

    test "returns all locks for a repository", ctx do
      {:ok, _} = LockManager.acquire(ctx.repo.id, "a.fbx", ctx.user.id)
      {:ok, _} = LockManager.acquire(ctx.repo.id, "b.fbx", ctx.user2.id)

      locks = LockManager.list_locks(ctx.repo.id)
      paths = Enum.map(locks, & &1.path) |> Enum.sort()

      assert paths == ["a.fbx", "b.fbx"]
    end

    test "does not return locks from other repositories", ctx do
      {:ok, other_repo} =
        Repo.insert(
          %Repository{owner_id: ctx.user.id}
          |> Repository.create_changeset(%{
            name: "other_#{unique_id()}",
            storage_path: "/data/repos/other"
          })
        )

      {:ok, _} = LockManager.acquire(ctx.repo.id, "file.fbx", ctx.user.id)
      {:ok, _} = LockManager.acquire(other_repo.id, "other.fbx", ctx.user.id)

      locks = LockManager.list_locks(ctx.repo.id)
      assert length(locks) == 1
      assert hd(locks).path == "file.fbx"
    end
  end
end
