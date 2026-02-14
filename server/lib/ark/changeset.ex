defmodule Ark.Changeset do
  @moduledoc false

  import Ecto.Changeset

  @path_traversal_pattern ~r"(^|/)\.\.(/|$)"

  def validate_relative_path(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      cond do
        String.starts_with?(value, "/") ->
          [{field, "must be a relative path"}]

        Regex.match?(@path_traversal_pattern, value) ->
          [{field, "must not contain path traversal"}]

        true ->
          []
      end
    end)
  end

  def validate_safe_path(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      if Regex.match?(@path_traversal_pattern, value) do
        [{field, "must not contain path traversal"}]
      else
        []
      end
    end)
  end
end
