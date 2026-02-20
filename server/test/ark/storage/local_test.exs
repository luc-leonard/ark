defmodule Ark.Storage.LocalTest do
  use ExUnit.Case, async: false

  alias Ark.Storage.Local

  @test_data "hello, ark!"
  @test_hash :crypto.hash(:sha256, "hello, ark!") |> Base.encode16(case: :lower)

  setup do
    unique = System.unique_integer([:positive])
    root_dir = Path.join(System.tmp_dir!(), "ark_storage_test_#{unique}")

    File.mkdir_p!(root_dir)
    original_config = Application.get_env(:ark, Ark.Storage.Local)
    Application.put_env(:ark, Ark.Storage.Local, root_path: root_dir)

    on_exit(fn ->
      File.rm_rf!(root_dir)

      if original_config,
        do: Application.put_env(:ark, Ark.Storage.Local, original_config),
        else: Application.delete_env(:ark, Ark.Storage.Local)
    end)

    {:ok, root: root_dir, tmp_dir: Path.join(root_dir, ".tmp")}
  end

  defp read_blob(hash) do
    with {:ok, stream} <- Local.get_stream(hash) do
      {:ok, IO.iodata_to_binary(Enum.to_list(stream))}
    end
  end

  describe "store_stream/1" do
    test "stores data and returns its SHA-256 hash" do
      assert {:ok, hash} = Local.store_stream([@test_data])
      assert hash == @test_hash
      assert String.match?(hash, ~r/\A[a-f0-9]{64}\z/)
    end

    test "is idempotent (dedup)", ctx do
      {:ok, hash1} = Local.store_stream([@test_data])
      {:ok, hash2} = Local.store_stream([@test_data])
      assert hash1 == hash2

      <<prefix::binary-size(2), _rest::binary>> = hash1
      blob_dir = Path.join([ctx.root, prefix])
      assert length(File.ls!(blob_dir)) == 1, "expected exactly one blob file (dedup)"
    end

    test "different data produces different hashes" do
      assert {:ok, hash1} = Local.store_stream(["file_a"])
      assert {:ok, hash2} = Local.store_stream(["file_b"])
      refute hash1 == hash2
    end

    test "creates sharded directory structure", ctx do
      {:ok, hash} = Local.store_stream([@test_data])
      <<prefix::binary-size(2), rest::binary>> = hash

      expected_path = Path.join([ctx.root, prefix, rest])
      assert File.exists?(expected_path)
    end

    test "concatenates multiple chunks correctly" do
      chunks = ["hello", ", ", "ark!"]
      {:ok, hash} = Local.store_stream(chunks)
      assert hash == @test_hash
      assert {:ok, @test_data} = read_blob(hash)
    end

    test "handles empty stream" do
      empty_sha256 = :crypto.hash(:sha256, "") |> Base.encode16(case: :lower)
      {:ok, hash} = Local.store_stream([])
      assert hash == empty_sha256
      assert {:ok, ""} = read_blob(hash)
    end

    test "cleans up tmp directory after success", ctx do
      {:ok, _hash} = Local.store_stream(["some data"])

      case File.ls(ctx.tmp_dir) do
        {:ok, files} -> assert files == [], "expected tmp dir to be empty, got: #{inspect(files)}"
        {:error, :enoent} -> :ok
      end
    end

    test "tmp files do not pollute blob namespace", ctx do
      {:ok, _hash} = Local.store_stream(["some data"])

      entries = File.ls!(ctx.root)
      # .tmp is the only non-shard directory; shard dirs are [a-f0-9]{2}
      shard_pattern = ~r/\A[a-f0-9]{2}\z/

      non_shard = Enum.reject(entries, &Regex.match?(shard_pattern, &1))

      assert non_shard == [".tmp"],
             "expected only .tmp dir alongside shards, got: #{inspect(non_shard)}"
    end

    test "cleans up tmp file on exception" do
      bad_stream =
        Stream.resource(
          fn -> :ok end,
          fn :ok -> raise "boom" end,
          fn _ -> :ok end
        )

      assert_raise RuntimeError, "boom", fn ->
        Local.store_stream(bad_stream)
      end

      tmp_dir = Path.join(root_path_from_config(), ".tmp")

      case File.ls(tmp_dir) do
        {:ok, files} -> assert files == [], "tmp file leaked: #{inspect(files)}"
        {:error, :enoent} -> :ok
      end
    end
  end

  describe "get_stream/1" do
    test "streams stored data correctly" do
      {:ok, hash} = Local.store_stream([@test_data])
      {:ok, stream} = Local.get_stream(hash)
      assert IO.iodata_to_binary(Enum.to_list(stream)) == @test_data
    end

    test "returns multiple chunks with small chunk_size" do
      data = String.duplicate("x", 100)
      {:ok, hash} = Local.store_stream([data])
      {:ok, stream} = Local.get_stream(hash, 30)
      chunks = Enum.to_list(stream)
      assert length(chunks) == 4
      assert IO.iodata_to_binary(chunks) == data
    end

    test "returns :not_found for unknown hash" do
      unknown = String.duplicate("ab", 32)
      assert {:error, :not_found} = Local.get_stream(unknown)
    end

    test "returns :invalid_hash for malformed hash" do
      assert {:error, :invalid_hash} = Local.get_stream("not-a-hash")
      assert {:error, :invalid_hash} = Local.get_stream("../etc/passwd")
    end
  end

  describe "verify/1" do
    test "returns :ok for a valid blob" do
      {:ok, hash} = Local.store_stream([@test_data])
      assert :ok = Local.verify(hash)
    end

    test "returns :integrity_error when blob is corrupted", ctx do
      {:ok, hash} = Local.store_stream([@test_data])
      <<prefix::binary-size(2), rest::binary>> = hash
      blob_file = Path.join([ctx.root, prefix, rest])
      File.write!(blob_file, "corrupted content")
      assert {:error, :integrity_error} = Local.verify(hash)
    end

    test "returns :not_found for unknown hash" do
      unknown = String.duplicate("ab", 32)
      assert {:error, :not_found} = Local.verify(unknown)
    end

    test "returns :invalid_hash for malformed hash" do
      assert {:error, :invalid_hash} = Local.verify("not-a-hash")
    end
  end

  describe "exists?/1" do
    test "returns true for stored blob" do
      {:ok, hash} = Local.store_stream([@test_data])
      assert Local.exists?(hash)
    end

    test "returns false for unknown hash" do
      unknown = String.duplicate("ab", 32)
      refute Local.exists?(unknown)
    end

    test "returns false for invalid hash" do
      refute Local.exists?("../../etc/passwd")
      refute Local.exists?("too-short")
    end
  end

  describe "delete/1" do
    test "removes a stored blob" do
      {:ok, hash} = Local.store_stream([@test_data])
      assert :ok = Local.delete(hash)
      refute Local.exists?(hash)
    end

    test "returns :not_found for unknown hash" do
      unknown = String.duplicate("ab", 32)
      assert {:error, :not_found} = Local.delete(unknown)
    end

    test "returns :invalid_hash for malformed hash" do
      assert {:error, :invalid_hash} = Local.delete("../etc/passwd")
    end
  end

  describe "path traversal protection" do
    test "get_stream rejects a hash that would escape root" do
      assert {:error, :invalid_hash} = Local.get_stream("../etc/passwd")

      assert {:error, :invalid_hash} =
               Local.get_stream(
                 "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
               )
    end

    test "delete rejects path traversal attempts" do
      assert {:error, :invalid_hash} = Local.delete("../../etc/shadow")
    end

    test "exists? rejects path traversal attempts" do
      refute Local.exists?("../../etc/passwd")
    end
  end

  describe "purge_stale_tmp!/1" do
    test "removes tmp files older than threshold", ctx do
      tmp_dir = ctx.tmp_dir
      File.mkdir_p!(tmp_dir)

      stale_file = Path.join(tmp_dir, "123.tmp")
      File.write!(stale_file, "stale")
      # Backdate mtime by 2 hours
      two_hours_ago = System.os_time(:second) - 7_200
      File.touch!(stale_file, two_hours_ago)

      fresh_file = Path.join(tmp_dir, "456.tmp")
      File.write!(fresh_file, "fresh")

      Local.purge_stale_tmp!()

      refute File.exists?(stale_file), "stale tmp file should have been purged"
      assert File.exists?(fresh_file), "fresh tmp file should be preserved"
    end

    test "is safe to call on empty or missing tmp dir" do
      assert :ok = Local.purge_stale_tmp!()
    end
  end

  defp root_path_from_config do
    Application.fetch_env!(:ark, Ark.Storage.Local)[:root_path]
  end
end
