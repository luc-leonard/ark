defmodule Ark.Versioning.FileEntry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @actions [:add, :modify, :delete]

  schema "file_entries" do
    field :path, :string
    field :content_hash, :string
    field :size, :integer
    field :action, Ecto.Enum, values: @actions

    belongs_to :revision, Ark.Versioning.Revision

    timestamps(updated_at: false)
  end

  def create_changeset(file_entry, attrs) do
    file_entry
    |> cast(attrs, [:path, :content_hash, :size, :action])
    |> validate_required([:path, :content_hash, :size, :action, :revision_id])
    |> validate_number(:size, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:revision_id)
    |> unique_constraint([:revision_id, :path])
  end
end
