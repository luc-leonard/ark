defmodule Ark.Repositories.MemberTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.User
  alias Ark.Repositories.{Member, Repository}

  setup do
    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "member_user"}))

    {:ok, repo} =
      Repo.insert(
        %Repository{owner_id: user.id}
        |> Repository.create_changeset(%{
          name: "test-repo",
          storage_path: "/data/repos/test"
        })
      )

    {:ok, user: user, repo: repo}
  end

  describe "create_changeset/2" do
    test "valid attrs", %{user: user, repo: repo} do
      changeset =
        %Member{repository_id: repo.id, user_id: user.id}
        |> Member.create_changeset(%{role: :write})

      assert changeset.valid?
    end

    test "requires mandatory fields" do
      changeset = Member.create_changeset(%Member{}, %{})

      assert %{
               role: ["can't be blank"],
               repository_id: ["can't be blank"],
               user_id: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates role enum", %{user: user, repo: repo} do
      changeset =
        %Member{repository_id: repo.id, user_id: user.id}
        |> Member.create_changeset(%{role: :superadmin})

      assert %{role: [_]} = errors_on(changeset)
    end

    test "enforces unique {repository_id, user_id}", %{user: user, repo: repo} do
      {:ok, _} =
        Repo.insert(
          %Member{repository_id: repo.id, user_id: user.id}
          |> Member.create_changeset(%{role: :write})
        )

      {:error, changeset} =
        Repo.insert(
          %Member{repository_id: repo.id, user_id: user.id}
          |> Member.create_changeset(%{role: :read})
        )

      assert %{repository_id: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
