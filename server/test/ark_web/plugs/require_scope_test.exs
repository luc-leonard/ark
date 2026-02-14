defmodule ArkWeb.Plugs.RequireScopeTest do
  use ArkWeb.ConnCase, async: true

  alias ArkWeb.Plugs.{ApiAuth, RequireScope}

  test "passes when scope is present", %{conn: conn} do
    {authed_conn, _user, _api_key, _raw_token} =
      setup_authenticated_conn(conn, scopes: [:repo_read, :lock])

    result =
      authed_conn
      |> ApiAuth.call([])
      |> RequireScope.call(:lock)

    refute result.halted
  end

  test "returns 403 when scope is missing", %{conn: conn} do
    {authed_conn, _user, _api_key, _raw_token} =
      setup_authenticated_conn(conn, scopes: [:repo_read])

    result =
      authed_conn
      |> ApiAuth.call([])
      |> RequireScope.call(:admin)

    assert result.halted
    assert result.status == 403
    assert Jason.decode!(result.resp_body)["reason"] == "missing_scope"
  end
end
