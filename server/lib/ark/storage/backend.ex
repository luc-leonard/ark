defmodule Ark.Storage.Backend do
  @moduledoc """
  Behaviour for content-addressable blob storage backends.

  Each backend stores binary data keyed by its SHA-256 hash,
  providing natural deduplication: identical content produces
  the same hash and is stored only once.

  Backends operate exclusively through streams to safely handle
  arbitrarily large files without loading them into memory:

  - `store_stream/1` — accepts an `Enumerable` of binary chunks,
    writing to disk incrementally.
  - `get_stream/1` — returns a lazy `Stream` of binary chunks,
    allowing large blobs to be read without loading them entirely
    into memory.
  """

  @type hash :: String.t()

  @doc "Stores streamed binary data and returns its SHA-256 hex digest."
  @callback store_stream(Enumerable.t()) :: {:ok, hash()} | {:error, term()}

  @doc """
  Returns a lazy stream of binary chunks for the given blob.

  The returned stream may raise on I/O errors during consumption.
  This follows the same convention as `File.stream!/3`.
  """
  @callback get_stream(hash()) :: {:ok, Enumerable.t()} | {:error, :not_found | :invalid_hash}

  @doc "Verifies that a stored blob matches its expected SHA-256 hash."
  @callback verify(hash()) :: :ok | {:error, :not_found | :invalid_hash | :integrity_error}

  @doc "Checks whether a blob with the given hash exists."
  @callback exists?(hash()) :: boolean()

  @doc "Deletes a blob by its SHA-256 hex digest."
  @callback delete(hash()) :: :ok | {:error, :not_found | :invalid_hash}
end
