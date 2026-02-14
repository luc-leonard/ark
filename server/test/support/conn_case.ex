defmodule ArkWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use ArkWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint ArkWeb.Endpoint

      use ArkWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import ArkWeb.ConnCase
    end
  end

  setup tags do
    Ark.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Creates a user with an API key and returns
  `{conn_with_auth_header, user, api_key, raw_token}`.

  ## Options

    * `:scopes` - list of scopes, defaults to `[:repo_read, :repo_write, :lock]`
    * `:username` - username, defaults to a unique string
  """
  def setup_authenticated_conn(conn, opts \\ []) do
    alias Ark.Accounts
    alias Ark.Accounts.User
    alias Ark.Repo

    scopes = Keyword.get(opts, :scopes, [:repo_read, :repo_write, :lock])
    username = Keyword.get(opts, :username, "user_#{System.unique_integer([:positive])}")

    {:ok, user} = Repo.insert(User.create_changeset(%User{}, %{username: username}))

    {:ok, api_key, raw_token} =
      Accounts.create_api_key(user, %{
        name: "test-key",
        scopes: scopes,
        expires_at: DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)
      })

    authed_conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> raw_token)
      |> Plug.Conn.put_req_header("content-type", "application/json")

    {authed_conn, user, api_key, raw_token}
  end
end
