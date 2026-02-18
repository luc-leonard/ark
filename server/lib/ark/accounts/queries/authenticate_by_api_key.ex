defmodule Ark.Accounts.Queries.AuthenticateByApiKey do
  @moduledoc false

  alias Ark.Accounts.{ApiKey, TokenGenerator}
  alias Ark.Repo

  import Ecto.Query

  @spec call(String.t()) ::
          {:ok, ApiKey.t()} | {:error, :invalid_token | :expired | :revoked}
  def call(raw_token) when is_binary(raw_token) do
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

  def call(_), do: {:error, :invalid_token}

  defp touch_last_used(%ApiKey{} = api_key) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case Repo.update(Ecto.Changeset.change(api_key, last_used_at: now)) do
      {:ok, updated} -> {:ok, updated}
      {:error, _} -> {:ok, api_key}
    end
  end
end
