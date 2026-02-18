defmodule Ark.Locking.Queries.GetLock do
  @moduledoc false

  alias Ark.Locking.Lock
  alias Ark.Repo

  @spec call(Ecto.UUID.t()) :: Lock.t() | nil
  def call(lock_id) do
    Repo.get(Lock, lock_id)
  end
end
