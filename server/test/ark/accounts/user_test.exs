defmodule Ark.Accounts.UserTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.User

  @valid_attrs %{username: "alice"}

  describe "create_changeset/2" do
    test "valid attrs" do
      changeset = User.create_changeset(%User{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires username" do
      changeset = User.create_changeset(%User{}, %{})
      assert %{username: ["can't be blank"]} = errors_on(changeset)
    end

    test "enforces unique username" do
      {:ok, _} = Repo.insert(User.create_changeset(%User{}, @valid_attrs))

      {:error, changeset} =
        Repo.insert(User.create_changeset(%User{}, @valid_attrs))

      assert %{username: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
