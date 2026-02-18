defmodule Ark.Accounts.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @scopes [:repo_read, :repo_write, :lock, :admin]

  schema "api_keys" do
    field :key_hash, :string
    field :key_prefix, :string
    field :name, :string
    field :scopes, {:array, Ecto.Enum}, values: @scopes
    field :expires_at, :utc_datetime
    field :last_used_at, :utc_datetime
    field :auto_rotated_key_hash, :string
    field :auto_rotated_key_prefix, :string
    field :auto_rotate_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :user, Ark.Accounts.User

    timestamps(updated_at: false)
  end

  def create_changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :scopes, :expires_at])
    |> validate_required([:key_hash, :key_prefix, :name, :scopes, :expires_at, :user_id])
    |> validate_length(:scopes, min: 1)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:key_hash)
  end

  def revoke_changeset(api_key, now \\ DateTime.utc_now()) do
    api_key
    |> change(revoked_at: DateTime.truncate(now, :second))
  end

  def rotate_changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:auto_rotated_key_hash, :auto_rotated_key_prefix, :auto_rotate_at])
    |> validate_required([:auto_rotated_key_hash, :auto_rotated_key_prefix, :auto_rotate_at])
    |> validate_length(:auto_rotated_key_prefix, is: 8)
    |> unique_constraint(:auto_rotated_key_hash)
  end

  @spec has_scope?(%__MODULE__{}, atom()) :: boolean()
  def has_scope?(%__MODULE__{scopes: scopes}, scope) when is_atom(scope) do
    scope in scopes
  end
end
