defmodule Ark.Repo.Migrations.CreateLocks do
  use Ecto.Migration

  def change do
    create table(:locks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :path, :string, null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:locks, [:repository_id, :path])
    create index(:locks, [:user_id])
  end
end
