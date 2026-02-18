defmodule Ark.Versioning do
  @moduledoc """
  The Versioning context — manages revisions and file entries.
  """

  use Boundary, deps: [Ark.Repo, Ark.Changeset], exports: [Revision, FileEntry]
end
