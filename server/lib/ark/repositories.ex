defmodule Ark.Repositories do
  @moduledoc """
  The Repositories context — manages repositories and membership access control.
  """

  use Boundary, deps: [Ark.Repo, Ark.Changeset], exports: [Repository, Member]

  defdelegate get_repository(id), to: Ark.Repositories.Queries.GetRepository, as: :call

  defdelegate get_member(repository_id, user_id),
    to: Ark.Repositories.Queries.GetMember,
    as: :call

  defdelegate has_access?(repository_id, user_id),
    to: Ark.Repositories.Queries.HasAccess,
    as: :call

  defdelegate add_member(repository_id, user_id, role),
    to: Ark.Repositories.Operations.AddMember,
    as: :call
end
