defmodule Ark.Versioning.Lock do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "locks" do
    field :path, :string

    belongs_to :repository, Ark.Repositories.Repository
    belongs_to :user, Ark.Accounts.User

    timestamps(updated_at: false)
  end

  def create_changeset(lock, attrs) do
    lock
    |> cast(attrs, [:path])
    |> validate_required([:path, :repository_id, :user_id])
    |> foreign_key_constraint(:repository_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:repository_id, :path])
  end
end
