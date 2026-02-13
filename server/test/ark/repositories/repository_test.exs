defmodule Ark.Repositories.RepositoryTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.User
  alias Ark.Repositories.Repository

  setup do
    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "owner"}))
    {:ok, user: user}
  end

  defp valid_attrs(owner_id) do
    %{name: "my-project", storage_path: "/data/repos/my-project", owner_id: owner_id}
  end

  describe "create_changeset/2" do
    test "valid attrs", %{user: user} do
      changeset = Repository.create_changeset(%Repository{}, valid_attrs(user.id))
      assert changeset.valid?
    end

    test "requires mandatory fields" do
      changeset = Repository.create_changeset(%Repository{}, %{})

      assert %{
               name: ["can't be blank"],
               storage_path: ["can't be blank"],
               owner_id: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "enforces unique name", %{user: user} do
      attrs = valid_attrs(user.id)
      {:ok, _} = Repo.insert(Repository.create_changeset(%Repository{}, attrs))

      {:error, changeset} =
        Repo.insert(
          Repository.create_changeset(%Repository{}, %{attrs | storage_path: "/other"})
        )

      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "update_changeset/2" do
    test "updates description", %{user: user} do
      {:ok, repo} = Repo.insert(Repository.create_changeset(%Repository{}, valid_attrs(user.id)))

      changeset =
        Repository.update_changeset(repo, %{description: "A game assets repo"})

      assert changeset.valid?
    end
  end
end
