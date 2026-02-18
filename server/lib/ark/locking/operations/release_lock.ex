defmodule Ark.Locking.Operations.ReleaseLock do
  @moduledoc false

  require Logger

  alias Ark.Locking.Lock
  alias Ark.Repo

  @spec call(Ecto.UUID.t()) :: :ok | {:error, :release_failed}
  def call(lock_id) do
    case Repo.get(Lock, lock_id) do
      nil ->
        :ok

      lock ->
        case Repo.delete(lock) do
          {:ok, _} ->
            :ok

          {:error, changeset} ->
            Logger.error("Failed to release lock #{lock_id}: #{inspect(changeset.errors)}")
            {:error, :release_failed}
        end
    end
  end
end
