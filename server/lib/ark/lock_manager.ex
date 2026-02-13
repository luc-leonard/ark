defmodule Ark.LockManager do
  @moduledoc """
  Manages exclusive file locks for Ark.

  Delegates lock operations to the database via Ecto.
  The GenServer serializes lock acquisition to prevent race conditions.
  """

  use GenServer

  alias Ark.Repo
  alias Ark.Versioning.Lock

  import Ecto.Query

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Acquire an exclusive lock on `path` for `user_id` in `repository_id`."
  def acquire(repository_id, path, user_id) do
    GenServer.call(__MODULE__, {:acquire, repository_id, path, user_id})
  end

  @doc "Release the lock on `path` in `repository_id`."
  def release(repository_id, path) do
    GenServer.call(__MODULE__, {:release, repository_id, path})
  end

  @doc "List all current locks for `repository_id`."
  def list_locks(repository_id) do
    GenServer.call(__MODULE__, {:list, repository_id})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:acquire, repository_id, path, user_id}, _from, state) do
    case Repo.one(lock_query(repository_id, path)) do
      nil ->
        changeset =
          Lock.create_changeset(%Lock{}, %{
            path: path,
            repository_id: repository_id,
            user_id: user_id
          })

        case Repo.insert(changeset) do
          {:ok, _lock} -> {:reply, :ok, state}
          {:error, _changeset} -> {:reply, {:error, :insert_failed}, state}
        end

      %Lock{user_id: ^user_id} ->
        {:reply, :ok, state}

      %Lock{user_id: holder_id} ->
        {:reply, {:error, :already_locked, holder_id}, state}
    end
  end

  @impl true
  def handle_call({:release, repository_id, path}, _from, state) do
    case Repo.one(lock_query(repository_id, path)) do
      nil -> :ok
      lock -> Repo.delete(lock)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:list, repository_id}, _from, state) do
    locks =
      Lock
      |> where([l], l.repository_id == ^repository_id)
      |> Repo.all()

    {:reply, locks, state}
  end

  defp lock_query(repository_id, path) do
    Lock
    |> where([l], l.repository_id == ^repository_id and l.path == ^path)
  end
end
