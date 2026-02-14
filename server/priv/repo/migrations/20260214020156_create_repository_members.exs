defmodule Ark.Repo.Migrations.CreateRepositoryMembers do
  use Ecto.Migration

  def change do
    create table(:repository_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:repository_members, [:repository_id, :user_id])
    create index(:repository_members, [:user_id])
  end
end
