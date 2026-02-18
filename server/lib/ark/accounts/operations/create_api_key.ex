defmodule Ark.Accounts.Operations.CreateApiKey do
  @moduledoc false

  alias Ark.Accounts.{ApiKey, TokenGenerator, User}
  alias Ark.Repo

  @spec call(User.t(), map()) ::
          {:ok, ApiKey.t(), raw_token :: String.t()} | {:error, Ecto.Changeset.t()}
  def call(%User{} = user, attrs) do
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
end
