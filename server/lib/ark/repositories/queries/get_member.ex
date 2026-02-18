defmodule Ark.Repositories.Queries.GetMember do
  @moduledoc false

  alias Ark.Repo
  alias Ark.Repositories.Member

  import Ecto.Query

  @spec call(Ecto.UUID.t(), Ecto.UUID.t()) :: Member.t() | nil
  def call(repository_id, user_id) do
    Repo.one(
      from(m in Member,
        where: m.repository_id == ^repository_id and m.user_id == ^user_id
      )
    )
  end
end
