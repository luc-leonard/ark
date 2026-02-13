defmodule Ark.Versioning.RevisionTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.User
  alias Ark.Repositories.Repository
  alias Ark.Versioning.Revision

  setup do
    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "dev"}))

    {:ok, repo} =
      Repo.insert(
        Repository.create_changeset(%Repository{}, %{
          name: "project",
          storage_path: "/data/repos/project",
          owner_id: user.id
        })
      )

    {:ok, user: user, repo: repo}
  end

  describe "create_changeset/2" do
    test "valid attrs", %{user: user, repo: repo} do
      changeset =
        Revision.create_changeset(%Revision{}, %{
          revision_number: 1,
          message: "Initial commit",
          repository_id: repo.id,
          author_id: user.id
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
        Revision.create_changeset(%Revision{}, %{
          revision_number: 1,
          repository_id: repo.id,
          author_id: user.id
        })

      assert changeset.valid?
    end

    test "validates revision_number > 0", %{user: user, repo: repo} do
      changeset =
        Revision.create_changeset(%Revision{}, %{
          revision_number: 0,
          repository_id: repo.id,
          author_id: user.id
        })

      assert %{revision_number: [_]} = errors_on(changeset)
    end

    test "enforces unique {repository_id, revision_number}", %{user: user, repo: repo} do
      attrs = %{revision_number: 1, repository_id: repo.id, author_id: user.id}
      {:ok, _} = Repo.insert(Revision.create_changeset(%Revision{}, attrs))

      {:error, changeset} =
        Repo.insert(
          Revision.create_changeset(%Revision{}, Map.put(attrs, :message, "dup"))
        )

      assert %{repository_id: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
