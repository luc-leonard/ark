defmodule Ark.ChangesetTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset
  import Ark.Changeset

  defp changeset(path) do
    {%{}, %{path: :string}}
    |> cast(%{path: path}, [:path])
  end

  describe "validate_relative_path/2" do
    test "accepts relative paths" do
      assert (changeset("models/hero.fbx") |> validate_relative_path(:path)).valid?
      assert (changeset("file.txt") |> validate_relative_path(:path)).valid?
      assert (changeset("a/b/c/d.png") |> validate_relative_path(:path)).valid?
    end

    test "rejects absolute paths" do
      refute (changeset("/etc/passwd") |> validate_relative_path(:path)).valid?
      refute (changeset("/models/hero.fbx") |> validate_relative_path(:path)).valid?
    end

    test "rejects path traversal" do
      refute (changeset("../secret") |> validate_relative_path(:path)).valid?
      refute (changeset("a/../../b") |> validate_relative_path(:path)).valid?
      refute (changeset("a/b/../..") |> validate_relative_path(:path)).valid?
    end

    test "allows single dots in path components" do
      assert (changeset("models/.hidden") |> validate_relative_path(:path)).valid?
      assert (changeset("a/b.c/d") |> validate_relative_path(:path)).valid?
    end

    test "normalizes leading ./" do
      cs = changeset("./file.fbx") |> validate_relative_path(:path)
      assert cs.valid?
      assert get_change(cs, :path) == "file.fbx"
    end

    test "normalizes double slashes" do
      cs = changeset("models//hero.fbx") |> validate_relative_path(:path)
      assert cs.valid?
      assert get_change(cs, :path) == "models/hero.fbx"
    end

    test "normalizes trailing slash" do
      cs = changeset("models/textures/") |> validate_relative_path(:path)
      assert cs.valid?
      assert get_change(cs, :path) == "models/textures"
    end

    test "normalizes combined issues" do
      cs = changeset("./a//b///c/") |> validate_relative_path(:path)
      assert cs.valid?
      assert get_change(cs, :path) == "a/b/c"
    end

    test "rejects traversal even after normalization" do
      refute (changeset("./../../etc") |> validate_relative_path(:path)).valid?
    end
  end

  describe "validate_safe_path/2" do
    test "accepts absolute paths without traversal" do
      assert (changeset("/data/repos/project") |> validate_safe_path(:path)).valid?
    end

    test "rejects path traversal" do
      refute (changeset("/data/../../../etc") |> validate_safe_path(:path)).valid?
      refute (changeset("../secret") |> validate_safe_path(:path)).valid?
    end
  end
end
