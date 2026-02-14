defmodule Ark.Repositories do
  @moduledoc """
  The Repositories context — manages repositories and membership access control.
  """

  alias Ark.Repo
  alias Ark.Repositories.{Member, Repository}

  import Ecto.Query

  @spec get_repository(Ecto.UUID.t()) :: Repository.t() | nil
  def get_repository(id), do: Repo.get(Repository, id)

  @spec get_member(Ecto.UUID.t(), Ecto.UUID.t()) :: Member.t() | nil
  def get_member(repository_id, user_id) do
    Repo.one(
      from(m in Member,
        where: m.repository_id == ^repository_id and m.user_id == ^user_id
      )
    )
  end

  @spec has_access?(Ecto.UUID.t(), Ecto.UUID.t()) :: boolean()
  def has_access?(repository_id, user_id) do
    Repo.exists?(
      from(m in Member,
        where: m.repository_id == ^repository_id and m.user_id == ^user_id
      )
    )
  end

  @spec add_member(Ecto.UUID.t(), Ecto.UUID.t(), atom()) ::
          {:ok, Member.t()} | {:error, Ecto.Changeset.t()}
  def add_member(repository_id, user_id, role) do
    %Member{repository_id: repository_id, user_id: user_id}
    |> Member.create_changeset(%{role: role})
    |> Repo.insert()
  end
end
