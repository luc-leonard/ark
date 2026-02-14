defmodule Ark.Repo.Migrations.FixConstraintsAndTypes do
  use Ecto.Migration

  def change do
    # 7. Add on_delete to all foreign keys

    alter table(:api_keys) do
      modify :user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        from: references(:users, type: :binary_id)
    end

    alter table(:repositories) do
      modify :owner_id, references(:users, type: :binary_id, on_delete: :restrict),
        from: references(:users, type: :binary_id)
    end

    alter table(:revisions) do
      modify :repository_id,
             references(:repositories, type: :binary_id, on_delete: :delete_all),
             from: references(:repositories, type: :binary_id)

      modify :author_id, references(:users, type: :binary_id, on_delete: :restrict),
        from: references(:users, type: :binary_id)

      # 8. revision.message :string → :text
      modify :message, :text, from: :string
    end

    alter table(:file_entries) do
      modify :revision_id, references(:revisions, type: :binary_id, on_delete: :delete_all),
        from: references(:revisions, type: :binary_id)
    end

    alter table(:locks) do
      modify :repository_id,
             references(:repositories, type: :binary_id, on_delete: :delete_all),
             from: references(:repositories, type: :binary_id)

      modify :user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        from: references(:users, type: :binary_id)
    end

    # 9. repositories: unique on [:name] → [:owner_id, :name]
    drop unique_index(:repositories, [:name])
    create unique_index(:repositories, [:owner_id, :name])

    # 10. file_entries: index → unique_index on [:revision_id, :path]
    drop index(:file_entries, [:revision_id, :path])
    create unique_index(:file_entries, [:revision_id, :path])
  end
end
