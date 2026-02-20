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
  - `[:ark, :storage, :exists]` — metadata: `%{hash: hash, hit: boolean}`
  - `[:ark, :storage, :delete]` — metadata: `%{hash: hash}`
  """

  use Boundary, deps: [], exports: [Backend]

  @backend Application.compile_env!(:ark, [__MODULE__, :backend])

  @spec store_stream(Enumerable.t()) :: {:ok, String.t()} | {:error, term()}
  def store_stream(enumerable) do
    with_telemetry(:store, %{}, fn -> @backend.store_stream(enumerable) end)
  end

  @spec get_stream(String.t()) ::
          {:ok, Enumerable.t()} | {:error, :not_found | :invalid_hash | term()}
  def get_stream(hash) do
    with_telemetry(:get, %{hash: hash}, fn -> @backend.get_stream(hash) end)
  end

  @spec verify(String.t()) :: :ok | {:error, :not_found | :invalid_hash | :integrity_error}
  def verify(hash) do
    with_telemetry(:verify, %{hash: hash}, fn -> @backend.verify(hash) end)
  end

  @spec exists?(String.t()) :: boolean()
  def exists?(hash) do
    with_telemetry(:exists, %{hash: hash}, fn -> @backend.exists?(hash) end)
  end

  @spec delete(String.t()) :: :ok | {:error, :not_found | :invalid_hash | term()}
  def delete(hash) do
    with_telemetry(:delete, %{hash: hash}, fn -> @backend.delete(hash) end)
  end

  @doc false
  @spec startup_cleanup :: :ok
  def startup_cleanup do
    if function_exported?(@backend, :purge_stale_tmp!, 1) do
      @backend.purge_stale_tmp!(3_600)
    end

    :ok
  end

  # -- Telemetry helpers -------------------------------------------------------

  defp with_telemetry(event, metadata, fun) do
    :telemetry.span([:ark, :storage, event], metadata, fn ->
      result = fun.()
      {result, stop_metadata(result, metadata)}
    end)
  end

  defp stop_metadata({:ok, hash}, meta) when is_binary(hash), do: Map.put(meta, :hash, hash)
  defp stop_metadata({:ok, _}, meta), do: meta
  defp stop_metadata(:ok, meta), do: meta
  defp stop_metadata({:error, reason}, meta), do: Map.put(meta, :error, reason)
  defp stop_metadata(bool, meta) when is_boolean(bool), do: Map.put(meta, :hit, bool)
end
