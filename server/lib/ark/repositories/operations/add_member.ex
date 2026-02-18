defmodule Ark.Repositories.Operations.AddMember do
  @moduledoc false

  alias Ark.Repo
  alias Ark.Repositories.Member

  @spec call(Ecto.UUID.t(), Ecto.UUID.t(), atom()) ::
          {:ok, Member.t()} | {:error, Ecto.Changeset.t()}
  def call(repository_id, user_id, role) do
    %Member{repository_id: repository_id, user_id: user_id}
    |> Member.create_changeset(%{role: role})
    |> Repo.insert()
  end
end
