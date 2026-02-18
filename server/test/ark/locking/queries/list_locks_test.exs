defmodule Ark.Locking.Queries.ListLocksTest do
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

  describe "list_locks/1" do
    test "returns empty list when no locks", ctx do
      assert [] = Locking.list_locks(ctx.repo.id)
    end

    test "returns all locks for a repository", ctx do
      {:ok, _} = Locking.acquire(ctx.repo.id, "a.fbx", ctx.user.id)
      {:ok, _} = Locking.acquire(ctx.repo.id, "b.fbx", ctx.user2.id)

      locks = Locking.list_locks(ctx.repo.id)
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

      {:ok, _} = Locking.acquire(ctx.repo.id, "file.fbx", ctx.user.id)
      {:ok, _} = Locking.acquire(other_repo.id, "other.fbx", ctx.user.id)

      locks = Locking.list_locks(ctx.repo.id)
      assert length(locks) == 1
      assert hd(locks).path == "file.fbx"
    end
  end
end
