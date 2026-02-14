defmodule Ark.LockManager do
  @moduledoc """
  Manages exclusive file locks for Ark.

  Lock exclusivity is enforced by a unique database constraint
  on `(repository_id, path)`. All operations are direct DB calls
  with no process serialization.
  """

  require Logger

  alias Ark.Repo
  alias Ark.Versioning.Lock

  import Ecto.Query

  @doc "Acquire an exclusive lock on `path` for `user_id` in `repository_id`."
  def acquire(repository_id, path, user_id) do
    changeset =
      %Lock{repository_id: repository_id, user_id: user_id}
      |> Lock.create_changeset(%{path: path})

    case Repo.insert(changeset) do
      {:ok, lock} ->
        {:ok, lock}

      {:error, %Ecto.Changeset{errors: errors}} ->
        if unique_violation?(errors) do
          handle_existing_lock(repository_id, path, user_id)
        else
          {:error, :insert_failed}
        end
    end
  end

  @doc "Release a lock by its ID."
  def release(lock_id) do
    case Repo.get(Lock, lock_id) do
      nil ->
        :ok

      lock ->
        case Repo.delete(lock) do
          {:ok, _} ->
            :ok

          {:error, changeset} ->
            Logger.error("Failed to release lock #{lock_id}: #{inspect(changeset.errors)}")
            :ok
        end
    end
  end

  @doc "List all current locks for `repository_id`."
  def list_locks(repository_id) do
    Lock
    |> where([l], l.repository_id == ^repository_id)
    |> Repo.all()
  end

  defp handle_existing_lock(repository_id, path, user_id) do
    case Repo.one(lock_query(repository_id, path)) do
      %Lock{user_id: ^user_id} = lock ->
        {:ok, lock}

      %Lock{user_id: holder_id} ->
        {:error, :already_locked, holder_id}

      nil ->
        # Lock was released between our INSERT and SELECT — retry
        acquire(repository_id, path, user_id)
    end
  end

  defp unique_violation?(errors) do
    Keyword.has_key?(errors, :repository_id)
  end

  defp lock_query(repository_id, path) do
    Lock
    |> where([l], l.repository_id == ^repository_id and l.path == ^path)
  end
end
