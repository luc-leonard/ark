defmodule Ark.Locking.Operations.AcquireLock do
  @moduledoc false

  alias Ark.Locking.Lock
  alias Ark.Repo

  import Ecto.Query

  @max_retries 1

  @spec call(Ecto.UUID.t(), String.t(), Ecto.UUID.t()) ::
          {:ok, Lock.t()}
          | {:error, :already_locked, Ecto.UUID.t()}
          | {:error, :validation, Ecto.Changeset.t()}
          | {:error, :insert_failed}
  def call(repository_id, path, user_id, retries \\ @max_retries) do
    changeset =
      %Lock{repository_id: repository_id, user_id: user_id}
      |> Lock.create_changeset(%{path: path})

    case Repo.insert(changeset) do
      {:ok, lock} ->
        {:ok, lock}

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if unique_violation?(errors) do
          handle_existing_lock(repository_id, path, user_id, retries)
        else
          {:error, :validation, changeset}
        end
    end
  end

  defp handle_existing_lock(repository_id, path, user_id, retries) do
    case Repo.one(lock_query(repository_id, path)) do
      %Lock{user_id: ^user_id} = lock ->
        {:ok, lock}

      %Lock{user_id: holder_id} ->
        {:error, :already_locked, holder_id}

      nil when retries > 0 ->
        call(repository_id, path, user_id, retries - 1)

      nil ->
        {:error, :insert_failed}
    end
  end

  defp unique_violation?(errors) do
    case Keyword.get_values(errors, :path) do
      [{_msg, meta} | _] -> meta[:constraint] == :unique
      _ -> false
    end
  end

  defp lock_query(repository_id, path) do
    Lock
    |> where([l], l.repository_id == ^repository_id and l.path == ^path)
  end
end
