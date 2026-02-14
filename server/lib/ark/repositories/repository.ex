defmodule Ark.Repositories.Repository do
  use Ecto.Schema
  import Ecto.Changeset
  import Ark.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "repositories" do
    field :name, :string
    field :description, :string
    field :storage_path, :string

    belongs_to :owner, Ark.Accounts.User

    has_many :members, Ark.Repositories.Member
    has_many :revisions, Ark.Versioning.Revision
    has_many :locks, Ark.Versioning.Lock

    timestamps()
  end

  def create_changeset(repository, attrs) do
    repository
    |> cast(attrs, [:name, :description, :storage_path])
    |> validate_required([:name, :storage_path, :owner_id])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_safe_path(:storage_path)
    |> foreign_key_constraint(:owner_id)
    |> unique_constraint([:owner_id, :name], error_key: :name)
  end

  def update_changeset(repository, attrs) do
    repository
    |> cast(attrs, [:name, :description, :storage_path])
    |> validate_required([:name, :storage_path])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_safe_path(:storage_path)
    |> unique_constraint([:owner_id, :name], error_key: :name)
  end
end
