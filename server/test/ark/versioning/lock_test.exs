defmodule Ark.Versioning.LockTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.User
  alias Ark.Repositories.Repository
  alias Ark.Versioning.Lock

  setup do
    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "locker"}))

    {:ok, repo} =
      Repo.insert(
        %Repository{owner_id: user.id}
        |> Repository.create_changeset(%{
          name: "game",
          storage_path: "/data/repos/game"
        })
      )

    {:ok, user: user, repo: repo}
  end

  describe "create_changeset/2" do
    test "valid attrs", %{user: user, repo: repo} do
      changeset =
        %Lock{repository_id: repo.id, user_id: user.id}
        |> Lock.create_changeset(%{path: "models/character.fbx"})

      assert changeset.valid?
    end

    test "requires mandatory fields" do
      changeset = Lock.create_changeset(%Lock{}, %{})

      assert %{
               path: ["can't be blank"],
               repository_id: ["can't be blank"],
               user_id: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "enforces unique {repository_id, path}", %{user: user, repo: repo} do
      {:ok, _} =
        Repo.insert(
          %Lock{repository_id: repo.id, user_id: user.id}
          |> Lock.create_changeset(%{path: "models/character.fbx"})
        )

      {:ok, user2} = Repo.insert(User.create_changeset(%User{}, %{username: "other"}))

      {:error, changeset} =
        Repo.insert(
          %Lock{repository_id: repo.id, user_id: user2.id}
          |> Lock.create_changeset(%{path: "models/character.fbx"})
        )

      assert %{repository_id: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
