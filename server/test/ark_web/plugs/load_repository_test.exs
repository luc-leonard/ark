defmodule ArkWeb.Plugs.LoadRepositoryTest do
  use ArkWeb.ConnCase, async: true

  alias Ark.Repo
  alias Ark.Repositories
  alias Ark.Repositories.Repository
  alias ArkWeb.Plugs.{ApiAuth, LoadRepository}

  defp setup_with_repo(conn, opts) do
    {authed_conn, user, api_key, raw_token} = setup_authenticated_conn(conn)

    {:ok, repo} =
      Repo.insert(
        %Repository{owner_id: user.id}
        |> Repository.create_changeset(%{
          name: "test-repo",
          storage_path: "/data/repos/test"
        })
      )

    if Keyword.get(opts, :with_membership, false) do
      {:ok, _} = Repositories.add_member(repo.id, user.id, :write)
    end

    authed_conn =
      authed_conn
      |> ApiAuth.call([])
      |> Map.update!(:params, &Map.put(&1, "repository_id", repo.id))
      |> Map.update!(:path_params, &Map.put(&1, "repository_id", repo.id))

    {authed_conn, user, repo, api_key, raw_token}
  end

  describe "call/2" do
    test "assigns repository and membership when user has access", %{conn: conn} do
      {authed_conn, _user, repo, _api_key, _raw_token} =
        setup_with_repo(conn, with_membership: true)

      result = LoadRepository.call(authed_conn, [])

      refute result.halted
      assert result.assigns.repository.id == repo.id
      assert result.assigns.membership.repository_id == repo.id
    end

    test "returns 404 when repository does not exist", %{conn: conn} do
      {authed_conn, _user, _api_key, _raw_token} = setup_authenticated_conn(conn)

      authed_conn =
        authed_conn
        |> ApiAuth.call([])
        |> Map.update!(:params, &Map.put(&1, "repository_id", Ecto.UUID.generate()))
        |> Map.update!(:path_params, &Map.put(&1, "repository_id", Ecto.UUID.generate()))

      result = LoadRepository.call(authed_conn, [])

      assert result.halted
      assert result.status == 404
      assert Jason.decode!(result.resp_body)["reason"] == "repository_not_found"
    end

    test "returns 403 when user has no membership", %{conn: conn} do
      {authed_conn, _user, _repo, _api_key, _raw_token} =
        setup_with_repo(conn, with_membership: false)

      result = LoadRepository.call(authed_conn, [])

      assert result.halted
      assert result.status == 403
      assert Jason.decode!(result.resp_body)["reason"] == "repository_access_denied"
    end
  end
end
