defmodule Ark.Storage do
  @moduledoc """
  Content-addressable blob store for Ark.

  Stores file blobs keyed by their content hash (SHA-256),
  enabling deduplication and efficient retrieval of large binary files.

  Delegates to the backend configured via:

      config :ark, Ark.Storage, backend: Ark.Storage.Local

  ## Telemetry

  All data operations emit telemetry spans under `[:ark, :storage, <op>]`:

  - `[:ark, :storage, :store]` — metadata: `%{hash: hash}` on success
  - `[:ark, :storage, :get]` — metadata: `%{hash: hash}`
  - `[:ark, :storage, :verify]` — metadata: `%{hash: hash}`
  - `[:ark, :storage, :delete]` — metadata: `%{hash: hash}`
  """

  use Boundary, deps: [], exports: [Backend]

  @backend Application.compile_env!(:ark, [__MODULE__, :backend])

  @spec store_stream(Enumerable.t()) :: {:ok, String.t()} | {:error, term()}
  def store_stream(enumerable) do
    :telemetry.span([:ark, :storage, :store], %{}, fn ->
      result = @backend.store_stream(enumerable)

      metadata =
        case result do
          {:ok, hash} -> %{hash: hash}
          {:error, reason} -> %{error: reason}
        end

      {result, metadata}
    end)
  end

  @spec get_stream(String.t()) ::
          {:ok, Enumerable.t()} | {:error, :not_found | :invalid_hash | term()}
  def get_stream(hash) do
    :telemetry.span([:ark, :storage, :get], %{hash: hash}, fn ->
      result = @backend.get_stream(hash)

      metadata =
        case result do
          {:ok, _} -> %{hash: hash}
          {:error, reason} -> %{hash: hash, error: reason}
        end

      {result, metadata}
    end)
  end

  @spec verify(String.t()) :: :ok | {:error, :not_found | :invalid_hash | :integrity_error}
  def verify(hash) do
    :telemetry.span([:ark, :storage, :verify], %{hash: hash}, fn ->
      result = @backend.verify(hash)

      metadata =
        case result do
          :ok -> %{hash: hash}
          {:error, reason} -> %{hash: hash, error: reason}
        end

      {result, metadata}
    end)
  end

  @spec exists?(String.t()) :: boolean()
  defdelegate exists?(hash), to: @backend

  @spec delete(String.t()) :: :ok | {:error, :not_found | :invalid_hash | term()}
  def delete(hash) do
    :telemetry.span([:ark, :storage, :delete], %{hash: hash}, fn ->
      result = @backend.delete(hash)

      metadata =
        case result do
          :ok -> %{hash: hash}
          {:error, reason} -> %{hash: hash, error: reason}
        end

      {result, metadata}
    end)
  end

  @spec purge_stale_tmp!(non_neg_integer()) :: :ok
  defdelegate purge_stale_tmp!(max_age_s \\ 3_600), to: @backend
end
