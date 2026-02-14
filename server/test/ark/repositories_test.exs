defmodule Ark.RepositoriesTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.User
  alias Ark.Repositories
  alias Ark.Repositories.{Member, Repository}

  setup do
    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "alice"}))
    {:ok, user2} = Repo.insert(User.create_changeset(%User{}, %{username: "bob"}))

    {:ok, repo} =
      Repo.insert(
        %Repository{owner_id: user.id}
        |> Repository.create_changeset(%{
          name: "my-project",
          storage_path: "/data/repos/my-project"
        })
      )

    {:ok, user: user, user2: user2, repo: repo}
  end

  describe "get_repository/1" do
    test "returns repository when it exists", %{repo: repo} do
      assert %Repository{id: id} = Repositories.get_repository(repo.id)
      assert id == repo.id
    end

    test "returns nil when repository does not exist" do
      assert is_nil(Repositories.get_repository(Ecto.UUID.generate()))
    end
  end

  describe "add_member/3" do
    test "creates a membership", %{repo: repo, user: user} do
      assert {:ok, %Member{role: :write}} = Repositories.add_member(repo.id, user.id, :write)
    end

    test "returns error on duplicate membership", %{repo: repo, user: user} do
      {:ok, _} = Repositories.add_member(repo.id, user.id, :write)
      assert {:error, %Ecto.Changeset{}} = Repositories.add_member(repo.id, user.id, :read)
    end
  end

  describe "get_member/2" do
    test "returns member when it exists", %{repo: repo, user: user} do
      {:ok, _} = Repositories.add_member(repo.id, user.id, :admin)

      assert %Member{role: :admin} = Repositories.get_member(repo.id, user.id)
    end

    test "returns nil when no membership", %{repo: repo, user2: user2} do
      assert is_nil(Repositories.get_member(repo.id, user2.id))
    end
  end

  describe "has_access?/2" do
    test "returns true when user is a member", %{repo: repo, user: user} do
      {:ok, _} = Repositories.add_member(repo.id, user.id, :read)

      assert Repositories.has_access?(repo.id, user.id)
    end

    test "returns false when user is not a member", %{repo: repo, user2: user2} do
      refute Repositories.has_access?(repo.id, user2.id)
    end
  end
end
