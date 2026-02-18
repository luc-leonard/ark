defmodule Ark.Repositories.Queries.HasAccess do
  @moduledoc false

  alias Ark.Repo
  alias Ark.Repositories.Member

  import Ecto.Query

  @spec call(Ecto.UUID.t(), Ecto.UUID.t()) :: boolean()
  def call(repository_id, user_id) do
    Repo.exists?(
      from(m in Member,
        where: m.repository_id == ^repository_id and m.user_id == ^user_id
      )
    )
  end
end
