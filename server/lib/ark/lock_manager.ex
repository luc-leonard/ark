defmodule Ark.LockManager do
  @moduledoc """
  Manages exclusive file locks for Ark.

  Delegates lock operations to the database via Ecto.
  The GenServer serializes lock acquisition to prevent race conditions.
  """

  use GenServer

  require Logger

  alias Ark.Repo
  alias Ark.Versioning.Lock

  import Ecto.Query

  # Client API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, :no_state, name: name)
  end

  @doc "Acquire an exclusive lock on `path` for `user_id` in `repository_id`."
  def acquire(server \\ __MODULE__, repository_id, path, user_id) do
    GenServer.call(server, {:acquire, repository_id, path, user_id})
  end

  @doc "Release a lock by its ID."
  def release(server \\ __MODULE__, lock_id) do
    GenServer.call(server, {:release, lock_id})
  end

  @doc "List all current locks for `repository_id`."
  def list_locks(server \\ __MODULE__, repository_id) do
    GenServer.call(server, {:list, repository_id})
  end

  # Server callbacks

  @impl true
  def init(:no_state) do
    {:ok, :no_state}
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
          {:ok, lock} -> {:reply, {:ok, lock}, state}
          {:error, _changeset} -> {:reply, {:error, :insert_failed}, state}
        end

      %Lock{user_id: ^user_id} = lock ->
        {:reply, {:ok, lock}, state}

      %Lock{user_id: holder_id} ->
        {:reply, {:error, :already_locked, holder_id}, state}
    end
  end

  @impl true
  def handle_call({:release, lock_id}, _from, state) do
    case Repo.get(Lock, lock_id) do
      nil ->
        :ok

      lock ->
        case Repo.delete(lock) do
          {:ok, _} ->
            :ok

          {:error, changeset} ->
            Logger.error("Failed to release lock #{lock_id}: #{inspect(changeset.errors)}")
        end
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
