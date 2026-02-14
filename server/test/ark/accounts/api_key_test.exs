defmodule Ark.Accounts.ApiKeyTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.{ApiKey, User}

  setup do
    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "testuser"}))
    {:ok, user: user}
  end

  defp valid_attrs(user_id) do
    %{
      key_hash: :crypto.hash(:sha256, "raw-token") |> Base.encode16(case: :lower),
      key_prefix: "ark_1234",
      name: "CLI laptop",
      scopes: [:repo_read, :repo_write],
      expires_at: DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second),
      user_id: user_id
    }
  end

  describe "create_changeset/2" do
    test "valid attrs", %{user: user} do
      changeset = ApiKey.create_changeset(%ApiKey{}, valid_attrs(user.id))
      assert changeset.valid?
    end

    test "requires mandatory fields" do
      changeset = ApiKey.create_changeset(%ApiKey{}, %{})

      assert %{
               key_hash: ["can't be blank"],
               key_prefix: ["can't be blank"],
               name: ["can't be blank"],
               scopes: ["can't be blank"],
               expires_at: ["can't be blank"],
               user_id: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates key_prefix length", %{user: user} do
      attrs = valid_attrs(user.id) |> Map.put(:key_prefix, "short")
      changeset = ApiKey.create_changeset(%ApiKey{}, attrs)
      assert %{key_prefix: [_]} = errors_on(changeset)
    end

    test "enforces unique key_hash", %{user: user} do
      attrs = valid_attrs(user.id)
      {:ok, _} = Repo.insert(ApiKey.create_changeset(%ApiKey{}, attrs))

      attrs2 = %{attrs | name: "other key", key_prefix: "ark_5678"}
      {:error, changeset} = Repo.insert(ApiKey.create_changeset(%ApiKey{}, attrs2))
      assert %{key_hash: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "revoke_changeset/1" do
    test "sets revoked_at", %{user: user} do
      {:ok, api_key} = Repo.insert(ApiKey.create_changeset(%ApiKey{}, valid_attrs(user.id)))
      changeset = ApiKey.revoke_changeset(api_key)
      assert changeset.valid?
      assert changeset.changes.revoked_at
    end
  end

  describe "rotate_changeset/2" do
    test "valid rotation attrs", %{user: user} do
      {:ok, api_key} = Repo.insert(ApiKey.create_changeset(%ApiKey{}, valid_attrs(user.id)))

      attrs = %{
        auto_rotated_key_hash: :crypto.hash(:sha256, "new-token") |> Base.encode16(case: :lower),
        auto_rotated_key_prefix: "ark_newk",
        auto_rotate_at: DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second)
      }

      changeset = ApiKey.rotate_changeset(api_key, attrs)
      assert changeset.valid?
    end

    test "requires rotation fields", %{user: user} do
      {:ok, api_key} = Repo.insert(ApiKey.create_changeset(%ApiKey{}, valid_attrs(user.id)))
      changeset = ApiKey.rotate_changeset(api_key, %{})

      assert %{
               auto_rotated_key_hash: ["can't be blank"],
               auto_rotated_key_prefix: ["can't be blank"],
               auto_rotate_at: ["can't be blank"]
             } = errors_on(changeset)
    end
  end
end
