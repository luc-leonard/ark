defmodule Ark.Accounts do
  @moduledoc """
  The Accounts context — manages users and API key authentication.
  """

  use Boundary, deps: [Ark.Repo], exports: [User, ApiKey]

  alias Ark.Accounts.ApiKey

  defdelegate create_user(attrs), to: Ark.Accounts.Operations.CreateUser, as: :call
  defdelegate create_api_key(user, attrs), to: Ark.Accounts.Operations.CreateApiKey, as: :call

  defdelegate authenticate_by_api_key(raw_token),
    to: Ark.Accounts.Queries.AuthenticateByApiKey,
    as: :call

  defdelegate has_scope?(api_key, scope), to: ApiKey
end
