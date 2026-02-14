defmodule Ark.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "users" do
    field :username, :string

    has_many :api_keys, Ark.Accounts.ApiKey
    has_many :repositories, Ark.Repositories.Repository, foreign_key: :owner_id
    has_many :repository_memberships, Ark.Repositories.Member

    timestamps()
  end

  def create_changeset(user, attrs) do
    user
    |> cast(attrs, [:username])
    |> validate_required([:username])
    |> validate_length(:username, min: 1, max: 255)
    |> unique_constraint(:username)
  end
end
