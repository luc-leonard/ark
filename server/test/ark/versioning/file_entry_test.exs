defmodule Ark.Versioning.FileEntryTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.User
  alias Ark.Repositories.Repository
  alias Ark.Versioning.{FileEntry, Revision}

  setup do
    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "artist"}))

    {:ok, repo} =
      Repo.insert(
        %Repository{owner_id: user.id}
        |> Repository.create_changeset(%{
          name: "assets",
          storage_path: "/data/repos/assets"
        })
      )

    {:ok, revision} =
      Repo.insert(
        %Revision{repository_id: repo.id, author_id: user.id}
        |> Revision.create_changeset(%{revision_number: 1})
      )

    {:ok, revision: revision}
  end

  defp valid_attrs do
    %{
      path: "textures/hero.png",
      content_hash: :crypto.hash(:sha256, "blob") |> Base.encode16(case: :lower),
      size: 1024,
      action: :add
    }
  end

  describe "create_changeset/2" do
    test "valid attrs", %{revision: revision} do
      changeset =
        %FileEntry{revision_id: revision.id}
        |> FileEntry.create_changeset(valid_attrs())

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
      attrs = Map.put(valid_attrs(), :size, -1)

      changeset =
        %FileEntry{revision_id: revision.id}
        |> FileEntry.create_changeset(attrs)

      assert %{size: [_]} = errors_on(changeset)
    end

    test "validates action enum", %{revision: revision} do
      attrs = Map.put(valid_attrs(), :action, :rename)

      changeset =
        %FileEntry{revision_id: revision.id}
        |> FileEntry.create_changeset(attrs)

      assert %{action: [_]} = errors_on(changeset)
    end
  end
end
