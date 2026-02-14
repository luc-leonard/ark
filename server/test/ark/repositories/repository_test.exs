defmodule Ark.Repositories.RepositoryTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.User
  alias Ark.Repositories.Repository

  setup do
    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "owner"}))
    {:ok, user: user}
  end

  defp valid_changeset(owner_id, overrides \\ %{}) do
    attrs = Map.merge(%{name: "my-project", storage_path: "/data/repos/my-project"}, overrides)

    %Repository{owner_id: owner_id}
    |> Repository.create_changeset(attrs)
  end

  describe "create_changeset/2" do
    test "valid attrs", %{user: user} do
      changeset = valid_changeset(user.id)
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
      {:ok, _} = Repo.insert(valid_changeset(user.id))

      {:error, changeset} =
        Repo.insert(valid_changeset(user.id, %{storage_path: "/other"}))

      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "update_changeset/2" do
    test "updates description", %{user: user} do
      {:ok, repo} = Repo.insert(valid_changeset(user.id))

      changeset =
        Repository.update_changeset(repo, %{description: "A game assets repo"})

      assert changeset.valid?
    end
  end
end
