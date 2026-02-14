defmodule Ark.AccountsTest do
  use Ark.DataCase, async: true

  alias Ark.Accounts
  alias Ark.Accounts.{ApiKey, User}

  setup do
    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: "alice"}))
    {:ok, user: user}
  end

  defp valid_key_attrs do
    %{
      name: "CLI laptop",
      scopes: [:repo_read, :repo_write],
      expires_at: DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)
    }
  end

  describe "create_api_key/2" do
    test "returns {:ok, api_key, raw_token}", %{user: user} do
      assert {:ok, %ApiKey{} = api_key, raw_token} =
               Accounts.create_api_key(user, valid_key_attrs())

      assert String.starts_with?(raw_token, "ark_")
      assert api_key.user_id == user.id
      assert api_key.scopes == [:repo_read, :repo_write]
      assert api_key.name == "CLI laptop"
    end

    test "stored hash matches SHA-256 of raw_token", %{user: user} do
      {:ok, api_key, raw_token} = Accounts.create_api_key(user, valid_key_attrs())
      expected_hash = :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)
      assert api_key.key_hash == expected_hash
    end

    test "returns error on invalid attrs", %{user: user} do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_api_key(user, %{})
    end
  end

  describe "authenticate_by_api_key/1" do
    test "returns {:ok, api_key} with preloaded user for valid token", %{user: user} do
      {:ok, _api_key, raw_token} = Accounts.create_api_key(user, valid_key_attrs())

      assert {:ok, %ApiKey{} = authenticated} = Accounts.authenticate_by_api_key(raw_token)
      assert authenticated.user.id == user.id
      assert authenticated.user.username == "alice"
    end

    test "updates last_used_at", %{user: user} do
      {:ok, api_key, raw_token} = Accounts.create_api_key(user, valid_key_attrs())
      assert is_nil(api_key.last_used_at)

      {:ok, authenticated} = Accounts.authenticate_by_api_key(raw_token)
      assert authenticated.last_used_at
    end

    test "returns error for unknown token" do
      assert {:error, :invalid_token} = Accounts.authenticate_by_api_key("ark_doesnotexist")
    end

    test "returns error for nil" do
      assert {:error, :invalid_token} = Accounts.authenticate_by_api_key(nil)
    end

    test "returns error for expired token", %{user: user} do
      attrs = %{
        valid_key_attrs()
        | expires_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
      }

      {:ok, _api_key, raw_token} = Accounts.create_api_key(user, attrs)

      assert {:error, :expired} = Accounts.authenticate_by_api_key(raw_token)
    end

    test "returns error for revoked token", %{user: user} do
      {:ok, api_key, raw_token} = Accounts.create_api_key(user, valid_key_attrs())
      {:ok, _} = api_key |> ApiKey.revoke_changeset() |> Repo.update()

      assert {:error, :revoked} = Accounts.authenticate_by_api_key(raw_token)
    end
  end

  describe "has_scope?/2" do
    test "returns true when scope is present", %{user: user} do
      {:ok, api_key, _} = Accounts.create_api_key(user, valid_key_attrs())
      assert Accounts.has_scope?(api_key, :repo_read)
    end

    test "returns false when scope is missing", %{user: user} do
      {:ok, api_key, _} = Accounts.create_api_key(user, valid_key_attrs())
      refute Accounts.has_scope?(api_key, :admin)
    end
  end
end
