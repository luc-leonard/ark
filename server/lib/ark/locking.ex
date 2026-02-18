defmodule Ark.Locking do
  @moduledoc """
  The Locking context — manages exclusive file locks for repositories.

  Lock exclusivity is enforced by a unique database constraint
  on `(repository_id, path)`. All operations are direct DB calls
  with no process serialization.
  """

  use Boundary, deps: [Ark.Repo, Ark.Changeset], exports: [Lock]

  defdelegate acquire(repository_id, path, user_id),
    to: Ark.Locking.Operations.AcquireLock,
    as: :call

  defdelegate release(lock_id), to: Ark.Locking.Operations.ReleaseLock, as: :call
  defdelegate get_lock(lock_id), to: Ark.Locking.Queries.GetLock, as: :call
  defdelegate list_locks(repository_id), to: Ark.Locking.Queries.ListLocks, as: :call
end
