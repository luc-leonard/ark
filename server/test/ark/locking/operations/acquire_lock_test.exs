defmodule Ark.Locking.Operations.AcquireLockTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.User
  alias Ark.Locking
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
      assert {:ok, lock} = Locking.acquire(ctx.repo.id, "file.fbx", ctx.user.id)
      assert lock.path == "file.fbx"
      assert lock.user_id == ctx.user.id
    end

    test "is idempotent for the same user", ctx do
      assert {:ok, lock1} = Locking.acquire(ctx.repo.id, "file.fbx", ctx.user.id)
      assert {:ok, lock2} = Locking.acquire(ctx.repo.id, "file.fbx", ctx.user.id)
      assert lock1.id == lock2.id
    end

    test "rejects lock when held by another user", ctx do
      assert {:ok, _lock} = Locking.acquire(ctx.repo.id, "file.fbx", ctx.user.id)

      assert {:error, :already_locked, holder_id} =
               Locking.acquire(ctx.repo.id, "file.fbx", ctx.user2.id)

      assert holder_id == ctx.user.id
    end

    test "allows different paths to be locked independently", ctx do
      assert {:ok, _} = Locking.acquire(ctx.repo.id, "a.fbx", ctx.user.id)
      assert {:ok, _} = Locking.acquire(ctx.repo.id, "b.fbx", ctx.user2.id)
    end

    test "returns validation error for absolute path", ctx do
      assert {:error, :validation, changeset} =
               Locking.acquire(ctx.repo.id, "/etc/passwd", ctx.user.id)

      assert {"must be a relative path", _} = changeset.errors[:path]
    end

    test "returns validation error for path traversal", ctx do
      assert {:error, :validation, changeset} =
               Locking.acquire(ctx.repo.id, "a/../../etc", ctx.user.id)

      assert {"must not contain path traversal", _} = changeset.errors[:path]
    end
  end

  describe "acquire/3 concurrency" do
    test "exactly one wins when two users race for the same path", ctx do
      alias Ecto.Adapters.SQL.Sandbox

      repo_id = ctx.repo.id
      user_id = ctx.user.id
      user2_id = ctx.user2.id

      tasks =
        for uid <- [user_id, user2_id] do
          Task.async(fn ->
            receive do: (:go -> Locking.acquire(repo_id, "contested.fbx", uid))
          end)
        end

      for task <- tasks, do: Sandbox.allow(Ark.Repo, self(), task.pid)
      for task <- tasks, do: send(task.pid, :go)

      results = Task.await_many(tasks, 5_000)

      winners = Enum.filter(results, &match?({:ok, _}, &1))
      losers = Enum.filter(results, &match?({:error, :already_locked, _}, &1))

      assert length(winners) == 1
      assert length(losers) == 1
    end

    test "concurrent acquires by the same user are all idempotent", ctx do
      alias Ecto.Adapters.SQL.Sandbox

      repo_id = ctx.repo.id
      user_id = ctx.user.id

      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            receive do: (:go -> Locking.acquire(repo_id, "same.fbx", user_id))
          end)
        end

      for task <- tasks, do: Sandbox.allow(Ark.Repo, self(), task.pid)
      for task <- tasks, do: send(task.pid, :go)

      results = Task.await_many(tasks, 5_000)

      assert Enum.all?(results, &match?({:ok, _}, &1))

      lock_ids = Enum.map(results, fn {:ok, lock} -> lock.id end) |> Enum.uniq()
      assert length(lock_ids) == 1
    end
  end
end
