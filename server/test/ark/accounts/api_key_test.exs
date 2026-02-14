defmodule Ark.Accounts.ApiKeyTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts.{ApiKey, User}

  setup do
    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "testuser"}))
    {:ok, user: user}
  end

  defp build_api_key(user_id, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          name: "CLI laptop",
          scopes: [:repo_read, :repo_write],
          expires_at: DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)
        },
        overrides
      )

    hash =
      :crypto.hash(:sha256, "raw-token-#{System.unique_integer([:positive])}")
      |> Base.encode16(case: :lower)

    %ApiKey{user_id: user_id, key_hash: hash, key_prefix: "ark_1234"}
    |> ApiKey.create_changeset(attrs)
  end

  describe "create_changeset/2" do
    test "valid attrs", %{user: user} do
      changeset = build_api_key(user.id)
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

    test "enforces unique key_hash", %{user: user} do
      {:ok, existing} = Repo.insert(build_api_key(user.id))

      changeset =
        %ApiKey{user_id: user.id, key_hash: existing.key_hash, key_prefix: "ark_5678"}
        |> ApiKey.create_changeset(%{
          name: "other key",
          scopes: [:repo_read],
          expires_at: DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)
        })

      {:error, changeset} = Repo.insert(changeset)
      assert %{key_hash: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "revoke_changeset/1" do
    test "sets revoked_at", %{user: user} do
      {:ok, api_key} = Repo.insert(build_api_key(user.id))
      changeset = ApiKey.revoke_changeset(api_key)
      assert changeset.valid?
      assert changeset.changes.revoked_at
    end
  end

  describe "rotate_changeset/2" do
    test "valid rotation attrs", %{user: user} do
      {:ok, api_key} = Repo.insert(build_api_key(user.id))

      attrs = %{
        auto_rotated_key_hash: :crypto.hash(:sha256, "new-token") |> Base.encode16(case: :lower),
        auto_rotated_key_prefix: "ark_newk",
        auto_rotate_at: DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second)
      }

      changeset = ApiKey.rotate_changeset(api_key, attrs)
      assert changeset.valid?
    end

    test "requires rotation fields", %{user: user} do
      {:ok, api_key} = Repo.insert(build_api_key(user.id))
      changeset = ApiKey.rotate_changeset(api_key, %{})

      assert %{
               auto_rotated_key_hash: ["can't be blank"],
               auto_rotated_key_prefix: ["can't be blank"],
               auto_rotate_at: ["can't be blank"]
             } = errors_on(changeset)
    end
  end
end
