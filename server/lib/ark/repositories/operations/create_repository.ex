defmodule Ark.Repositories.Operations.CreateRepository do
  @moduledoc false

  alias Ark.Repo
  alias Ark.Repositories.Repository

  @spec call(Ecto.UUID.t(), map()) :: {:ok, Repository.t()} | {:error, Ecto.Changeset.t()}
  def call(owner_id, attrs) do
    %Repository{owner_id: owner_id}
    |> Repository.create_changeset(attrs)
    |> Repo.insert()
  end
end
