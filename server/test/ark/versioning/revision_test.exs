defmodule Ark.Versioning.RevisionTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.User
  alias Ark.Repositories.Repository
  alias Ark.Versioning.Revision

  setup do
    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "dev"}))

    {:ok, repo} =
      Repo.insert(
        %Repository{owner_id: user.id}
        |> Repository.create_changeset(%{
          name: "project",
          storage_path: "/data/repos/project"
        })
      )

    {:ok, user: user, repo: repo}
  end

  describe "create_changeset/2" do
    test "valid attrs", %{user: user, repo: repo} do
      changeset =
        %Revision{repository_id: repo.id, author_id: user.id}
        |> Revision.create_changeset(%{
          revision_number: 1,
          message: "Initial commit"
        })

      assert changeset.valid?
    end

    test "requires mandatory fields" do
      changeset = Revision.create_changeset(%Revision{}, %{})

      assert %{
               revision_number: ["can't be blank"],
               repository_id: ["can't be blank"],
               author_id: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "message is optional", %{user: user, repo: repo} do
      changeset =
        %Revision{repository_id: repo.id, author_id: user.id}
        |> Revision.create_changeset(%{revision_number: 1})

      assert changeset.valid?
    end

    test "validates revision_number > 0", %{user: user, repo: repo} do
      changeset =
        %Revision{repository_id: repo.id, author_id: user.id}
        |> Revision.create_changeset(%{revision_number: 0})

      assert %{revision_number: [_]} = errors_on(changeset)
    end

    test "enforces unique {repository_id, revision_number}", %{user: user, repo: repo} do
      {:ok, _} =
        Repo.insert(
          %Revision{repository_id: repo.id, author_id: user.id}
          |> Revision.create_changeset(%{revision_number: 1})
        )

      {:error, changeset} =
        Repo.insert(
          %Revision{repository_id: repo.id, author_id: user.id}
          |> Revision.create_changeset(%{revision_number: 1, message: "dup"})
        )

      assert %{revision_number: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
