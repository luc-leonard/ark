defmodule Ark.Storage.Local do
  @moduledoc """
  Local filesystem backend for content-addressable blob storage.

  Blobs are stored in a sharded directory structure derived from
  the SHA-256 hex digest: `<root>/<first 2 chars>/<remaining chars>`.
  This keeps directory sizes manageable even with millions of blobs.

  Writes are atomic (tmp file + rename) so a crash never leaves
  a half-written blob on disk. Temporary files live in `<root>/.tmp/`
  to guarantee same-filesystem rename and keep the blob namespace clean.
  """

  require Logger

  @behaviour Ark.Storage.Backend

  @hash_pattern ~r/\A[a-f0-9]{64}\z/
  @default_chunk_size 2 * 1024 * 1024
  @default_stale_threshold_s 3_600

  @doc """
  Deletes temporary files older than `max_age_s` seconds.

  Called at application startup to clean up orphans left by crashed writes.
  Any `.tmp` file that survived a restart is stale by definition.
  """
  @spec purge_stale_tmp!(non_neg_integer()) :: :ok
  def purge_stale_tmp!(max_age_s \\ @default_stale_threshold_s) do
    dir = tmp_dir()
    File.mkdir_p!(dir)

    case File.ls(dir) do
      {:ok, entries} ->
        now = System.os_time(:second)

        purged =
          Enum.count(entries, fn entry ->
            path = Path.join(dir, entry)

            case File.stat(path, time: :posix) do
              {:ok, %File.Stat{mtime: mtime}} when now - mtime > max_age_s ->
                File.rm(path)
                true

              _ ->
                false
            end
          end)

        if purged > 0, do: Logger.info("Purged #{purged} stale tmp file(s) from #{dir}")

        :ok

      {:error, :enoent} ->
        :ok
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  @impl true
  def store_stream(enumerable) do
    root = root_path()
    tmp = tmp_path()

    try do
      case stream_and_hash(enumerable, tmp) do
        {:ok, hash} ->
          place_blob(tmp, hash, root)

        {:error, reason} ->
          File.rm(tmp)
          {:error, reason}
      end
    rescue
      e ->
        File.rm(tmp)
        reraise e, __STACKTRACE__
    end
  end

  @impl true
  def verify(hash) do
    root = root_path()

    with :ok <- validate_hash(hash) do
      path = blob_path(hash, root)

      case :file.open(path, [:read, :raw, :binary]) do
        {:ok, fd} ->
          try do
            case hash_fd(fd) do
              {:ok, computed} when computed == hash -> :ok
              {:ok, _} -> {:error, :integrity_error}
              {:error, reason} -> {:error, reason}
            end
          after
            :file.close(fd)
          end

        {:error, :enoent} ->
          {:error, :not_found}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @impl true
  def get_stream(hash), do: get_stream(hash, @default_chunk_size)

  @doc """
  Like `get_stream/1` but with a configurable chunk size in bytes.

  The returned stream raises on I/O errors during consumption,
  following the same convention as `File.stream!/3`. Callers that
  need graceful mid-stream error handling should wrap consumption
  in a `try/rescue` block.

  This is specific to the local backend and not part of the `Backend` behaviour.
  """
  @spec get_stream(String.t(), pos_integer()) ::
          {:ok, Enumerable.t()} | {:error, :not_found | :invalid_hash | term()}
  def get_stream(hash, chunk_size) do
    root = root_path()

    with :ok <- validate_hash(hash) do
      path = blob_path(hash, root)

      if File.exists?(path) do
        stream =
          Stream.resource(
            fn ->
              case :file.open(path, [:read, :raw, :binary]) do
                {:ok, fd} ->
                  fd

                {:error, reason} ->
                  raise "Cannot open blob #{hash}: #{:file.format_error(reason)}"
              end
            end,
            fn fd ->
              case :file.read(fd, chunk_size) do
                {:ok, data} -> {[data], fd}
                :eof -> {:halt, fd}
                {:error, reason} -> raise "I/O error reading blob: #{:file.format_error(reason)}"
              end
            end,
            &:file.close/1
          )

        {:ok, stream}
      else
        {:error, :not_found}
      end
    end
  end

  @impl true
  def exists?(hash) do
    root = root_path()

    case validate_hash(hash) do
      :ok -> File.exists?(blob_path(hash, root))
      {:error, _} -> false
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  @impl true
  def delete(hash) do
    root = root_path()

    with :ok <- validate_hash(hash) do
      case File.rm(blob_path(hash, root)) do
        :ok -> :ok
        {:error, :enoent} -> {:error, :not_found}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # -- Private ---------------------------------------------------------------

  defp blob_path(hash, root) do
    <<prefix::binary-size(2), rest::binary>> = hash
    Path.join([root, prefix, rest])
  end

  defp validate_hash(hash) when is_binary(hash) do
    if Regex.match?(@hash_pattern, hash), do: :ok, else: {:error, :invalid_hash}
  end

  defp validate_hash(_), do: {:error, :invalid_hash}

  defp hash_fd(fd, state \\ :crypto.hash_init(:sha256)) do
    case :file.read(fd, @default_chunk_size) do
      {:ok, data} -> hash_fd(fd, :crypto.hash_update(state, data))
      :eof -> {:ok, state |> :crypto.hash_final() |> Base.encode16(case: :lower)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp root_path do
    :ark
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(:root_path)
  end

  defp tmp_dir do
    Path.join(root_path(), ".tmp")
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp tmp_path do
    dir = tmp_dir()
    File.mkdir_p!(dir)
    Path.join(dir, "#{System.unique_integer([:positive])}.tmp")
  end

  defp stream_and_hash(enumerable, tmp) do
    case :file.open(tmp, [:write, :raw]) do
      {:ok, fd} ->
        try do
          enumerable
          |> Enum.reduce_while({:ok, :crypto.hash_init(:sha256)}, fn chunk, {:ok, state} ->
            case :file.write(fd, chunk) do
              :ok -> {:cont, {:ok, :crypto.hash_update(state, chunk)}}
              {:error, reason} -> {:halt, {:error, reason}}
            end
          end)
          |> case do
            {:ok, state} ->
              :ok = :file.sync(fd)
              hash = state |> :crypto.hash_final() |> Base.encode16(case: :lower)
              {:ok, hash}

            {:error, reason} ->
              {:error, reason}
          end
        after
          :file.close(fd)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Best-effort fsync on the parent directory to flush the new directory entry.
  # After rename succeeds the blob is already on disk — this only guards against
  # metadata loss on power failure. Logged on failure so admins can investigate
  # (WSL2 and some FUSE mounts don't support fsync on directories).
  defp sync_dir(path) do
    case :file.open(path, [:read, :raw]) do
      {:ok, fd} ->
        case :file.sync(fd) do
          :ok ->
            :ok

          {:error, reason} ->
            emit_sync_dir_failure(path, reason)
        end

        :file.close(fd)

      {:error, reason} ->
        emit_sync_dir_failure(path, reason)
    end

    :ok
  end

  defp emit_sync_dir_failure(path, reason) do
    Logger.debug("fsync failed on directory #{path}: #{:file.format_error(reason)}")

    :telemetry.execute(
      [:ark, :storage, :sync_dir_failed],
      %{},
      %{path: path, reason: reason}
    )
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp place_blob(tmp, hash, root) do
    path = blob_path(hash, root)

    if File.exists?(path) do
      File.rm(tmp)
      {:ok, hash}
    else
      dir = Path.dirname(path)

      with :ok <- File.mkdir_p(dir),
           :ok <- File.rename(tmp, path),
           :ok <- sync_dir(dir) do
        {:ok, hash}
      else
        {:error, reason} ->
          File.rm(tmp)
          {:error, reason}
      end
    end
  end
end
