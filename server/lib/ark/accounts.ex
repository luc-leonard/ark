defmodule Ark.Accounts do
  @moduledoc """
  The Accounts context — manages users and API key authentication.
  """

  alias Ark.Accounts.{ApiKey, TokenGenerator, User}
  alias Ark.Repo

  import Ecto.Query

  @spec create_api_key(User.t(), map()) ::
          {:ok, ApiKey.t(), raw_token :: String.t()} | {:error, Ecto.Changeset.t()}
  def create_api_key(%User{} = user, attrs) do
    {raw_token, key_hash, key_prefix} = TokenGenerator.generate()

    result =
      %ApiKey{user_id: user.id, key_hash: key_hash, key_prefix: key_prefix}
      |> ApiKey.create_changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, api_key} -> {:ok, api_key, raw_token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @spec authenticate_by_api_key(String.t()) ::
          {:ok, ApiKey.t()} | {:error, :invalid_token | :expired | :revoked}
  def authenticate_by_api_key(raw_token) when is_binary(raw_token) do
    hash = TokenGenerator.hash(raw_token)

    case Repo.one(from(ak in ApiKey, where: ak.key_hash == ^hash, preload: :user)) do
      nil ->
        {:error, :invalid_token}

      %ApiKey{revoked_at: revoked_at} when not is_nil(revoked_at) ->
        {:error, :revoked}

      %ApiKey{expires_at: expires_at} = api_key ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :lt do
          {:error, :expired}
        else
          touch_last_used(api_key)
        end
    end
  end

  def authenticate_by_api_key(_), do: {:error, :invalid_token}

  @spec has_scope?(ApiKey.t(), atom()) :: boolean()
  def has_scope?(%ApiKey{scopes: scopes}, scope) when is_atom(scope) do
    scope in scopes
  end

  defp touch_last_used(%ApiKey{} = api_key) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    api_key
    |> Ecto.Changeset.change(last_used_at: now)
    |> Repo.update()
  end
end
