defmodule Ark.Locking.Operations.ReleaseLockTest do
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

  describe "release/1" do
    test "releases an existing lock", ctx do
      {:ok, lock} = Locking.acquire(ctx.repo.id, "file.fbx", ctx.user.id)
      assert :ok = Locking.release(lock.id)
      assert [] = Locking.list_locks(ctx.repo.id)
    end

    test "is safe to call on a non-existent lock" do
      assert :ok = Locking.release(Ecto.UUID.generate())
    end

    test "allows re-acquisition after release", ctx do
      {:ok, lock} = Locking.acquire(ctx.repo.id, "file.fbx", ctx.user.id)
      :ok = Locking.release(lock.id)
      assert {:ok, _} = Locking.acquire(ctx.repo.id, "file.fbx", ctx.user2.id)
    end
  end
end
