defmodule Ark.Repo.Migrations.CreateFileEntries do
  use Ecto.Migration

  def change do
    create table(:file_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :path, :string, null: false
      add :content_hash, :string, null: false
      add :size, :bigint, null: false
      add :action, :string, null: false

      add :revision_id, references(:revisions, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:file_entries, [:revision_id, :path])
  end
end
