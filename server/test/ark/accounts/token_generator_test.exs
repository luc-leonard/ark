defmodule Ark.Accounts.TokenGeneratorTest do
  use ExUnit.Case, async: true

  alias Ark.Accounts.TokenGenerator

  describe "generate/0" do
    test "returns a raw token starting with ark_" do
      {raw_token, _hash, _prefix} = TokenGenerator.generate()
      assert String.starts_with?(raw_token, "ark_")
    end

    test "returns a 36-character raw token" do
      {raw_token, _hash, _prefix} = TokenGenerator.generate()
      assert String.length(raw_token) == 36
    end

    test "key_prefix is the first 8 chars of the raw token" do
      {raw_token, _hash, prefix} = TokenGenerator.generate()
      assert prefix == String.slice(raw_token, 0, 8)
    end

    test "key_hash is a 64-char lowercase hex string" do
      {_raw_token, hash, _prefix} = TokenGenerator.generate()
      assert String.length(hash) == 64
      assert hash =~ ~r/^[0-9a-f]{64}$/
    end

    test "key_hash matches SHA-256 of raw_token" do
      {raw_token, hash, _prefix} = TokenGenerator.generate()
      expected = :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)
      assert hash == expected
    end

    test "generates unique tokens" do
      tokens = for _ <- 1..100, do: elem(TokenGenerator.generate(), 0)
      assert length(Enum.uniq(tokens)) == 100
    end
  end

  describe "hash/1" do
    test "is deterministic" do
      assert TokenGenerator.hash("ark_test") == TokenGenerator.hash("ark_test")
    end

    test "returns lowercase hex" do
      result = TokenGenerator.hash("anything")
      assert result =~ ~r/^[0-9a-f]+$/
    end
  end
end
