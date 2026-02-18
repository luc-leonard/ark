defmodule Ark.Accounts.Operations.CreateUser do
  @moduledoc false

  alias Ark.Accounts.User
  alias Ark.Repo

  @spec call(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def call(attrs) do
    %User{}
    |> User.create_changeset(attrs)
    |> Repo.insert()
  end
end
