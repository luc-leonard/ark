defmodule Ark.Locking.Queries.ListLocks do
  @moduledoc false

  alias Ark.Locking.Lock
  alias Ark.Repo

  import Ecto.Query

  @spec call(Ecto.UUID.t()) :: [Lock.t()]
  def call(repository_id) do
    Lock
    |> where([l], l.repository_id == ^repository_id)
    |> Repo.all()
  end
end
