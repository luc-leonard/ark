defmodule Ark.Versioning.Revision do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "revisions" do
    field :revision_number, :integer
    field :message, :string

    belongs_to :repository, Ark.Repositories.Repository
    belongs_to :author, Ark.Accounts.User

    has_many :file_entries, Ark.Versioning.FileEntry

    timestamps(updated_at: false)
  end

  def create_changeset(revision, attrs) do
    revision
    |> cast(attrs, [:revision_number, :message])
    |> validate_required([:revision_number, :repository_id, :author_id])
    |> validate_number(:revision_number, greater_than: 0)
    |> foreign_key_constraint(:repository_id)
    |> foreign_key_constraint(:author_id)
    |> unique_constraint([:repository_id, :revision_number], error_key: :revision_number)
  end
end
