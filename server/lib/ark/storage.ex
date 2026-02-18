defmodule Ark.Storage do
  @moduledoc """
  Content-addressable blob store for Ark.

  Stores file blobs keyed by their content hash (SHA-256),
  enabling deduplication and efficient retrieval of large binary files.
  """

  use Boundary, deps: [], exports: []
end
