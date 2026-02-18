defmodule Ark.Repositories.Queries.GetRepository do
  @moduledoc false

  alias Ark.Repo
  alias Ark.Repositories.Repository

  @spec call(Ecto.UUID.t()) :: Repository.t() | nil
  def call(id), do: Repo.get(Repository, id)
end
