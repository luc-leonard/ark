defmodule Ark.Repositories.Member do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @roles [:admin, :write, :read]

  schema "repository_members" do
    field :role, Ecto.Enum, values: @roles

    belongs_to :repository, Ark.Repositories.Repository
    belongs_to :user, Ark.Accounts.User

    timestamps()
  end

  def create_changeset(member, attrs) do
    member
    |> cast(attrs, [:role])
    |> validate_required([:role, :repository_id, :user_id])
    |> foreign_key_constraint(:repository_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:repository_id, :user_id])
  end
end
