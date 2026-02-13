defmodule Ark.LockManager do
  @moduledoc """
  Manages exclusive file locks for Ark.

  Provides a GenServer-based locking mechanism to ensure
  only one user can modify a given file path at a time.
  """

  use GenServer

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Acquire an exclusive lock on `path` for `user`."
  def acquire(path, user) do
    GenServer.call(__MODULE__, {:acquire, path, user})
  end

  @doc "Release the lock on `path`."
  def release(path) do
    GenServer.call(__MODULE__, {:release, path})
  end

  @doc "List all current locks."
  def list_locks do
    GenServer.call(__MODULE__, :list)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:acquire, path, user}, _from, locks) do
    case Map.get(locks, path) do
      nil ->
        {:reply, :ok, Map.put(locks, path, user)}

      ^user ->
        {:reply, :ok, locks}

      holder ->
        {:reply, {:error, :already_locked, holder}, locks}
    end
  end

  @impl true
  def handle_call({:release, path}, _from, locks) do
    {:reply, :ok, Map.delete(locks, path)}
  end

  @impl true
  def handle_call(:list, _from, locks) do
    entries =
      Enum.map(locks, fn {path, user} ->
        %{path: path, user: user}
      end)

    {:reply, entries, locks}
  end
end
