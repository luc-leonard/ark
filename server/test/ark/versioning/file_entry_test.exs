defmodule Ark.Versioning.FileEntryTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.User
  alias Ark.Repositories.Repository
  alias Ark.Versioning.{FileEntry, Revision}

  setup do
    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "artist"}))

    {:ok, repo} =
      Repo.insert(
        Repository.create_changeset(%Repository{}, %{
          name: "assets",
          storage_path: "/data/repos/assets",
          owner_id: user.id
        })
      )

    {:ok, revision} =
      Repo.insert(
        Revision.create_changeset(%Revision{}, %{
          revision_number: 1,
          repository_id: repo.id,
          author_id: user.id
        })
      )

    {:ok, revision: revision}
  end

  defp valid_attrs(revision_id) do
    %{
      path: "textures/hero.png",
      content_hash: :crypto.hash(:sha256, "blob") |> Base.encode16(case: :lower),
      size: 1024,
      action: :add,
      revision_id: revision_id
    }
  end

  describe "create_changeset/2" do
    test "valid attrs", %{revision: revision} do
      changeset = FileEntry.create_changeset(%FileEntry{}, valid_attrs(revision.id))
      assert changeset.valid?
    end

    test "requires mandatory fields" do
      changeset = FileEntry.create_changeset(%FileEntry{}, %{})

      assert %{
               path: ["can't be blank"],
               content_hash: ["can't be blank"],
               size: ["can't be blank"],
               action: ["can't be blank"],
               revision_id: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates size >= 0", %{revision: revision} do
      attrs = valid_attrs(revision.id) |> Map.put(:size, -1)
      changeset = FileEntry.create_changeset(%FileEntry{}, attrs)
      assert %{size: [_]} = errors_on(changeset)
    end

    test "validates action enum", %{revision: revision} do
      attrs = valid_attrs(revision.id) |> Map.put(:action, :rename)
      changeset = FileEntry.create_changeset(%FileEntry{}, attrs)
      assert %{action: [_]} = errors_on(changeset)
    end
  end
end
