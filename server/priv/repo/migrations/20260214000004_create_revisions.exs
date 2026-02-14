defmodule Ark.Repo.Migrations.CreateRevisions do
  use Ecto.Migration

  def change do
    create table(:revisions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :revision_number, :integer, null: false
      add :message, :text

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :author_id, references(:users, type: :binary_id, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:revisions, [:repository_id, :revision_number])
    create index(:revisions, [:author_id])
  end
end
