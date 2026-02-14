defmodule ArkWeb.Plugs.ApiAuth do
  @moduledoc """
  Plug that authenticates API requests via Bearer token.

  Extracts the token from the `Authorization: Bearer ark_...` header,
  authenticates via `Ark.Accounts`, and assigns `current_user` and
  `current_api_key` to the conn. Returns 401 JSON on failure.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with {:ok, raw_token} <- extract_token(conn),
         {:ok, api_key} <- Ark.Accounts.authenticate_by_api_key(raw_token) do
      conn
      |> assign(:current_user, api_key.user)
      |> assign(:current_api_key, api_key)
    else
      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized", reason: format_reason(reason)})
        |> halt()
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :missing_token}
    end
  end

  defp format_reason(:invalid_token), do: "invalid_token"
  defp format_reason(:missing_token), do: "missing_token"
  defp format_reason(:expired), do: "token_expired"
  defp format_reason(:revoked), do: "token_revoked"
end
