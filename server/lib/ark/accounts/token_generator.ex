defmodule Ark.Accounts.TokenGenerator do
  @moduledoc false

  @prefix "ark_"
  @random_chars 32
  @base62_alphabet Enum.concat([?0..?9, ?A..?Z, ?a..?z]) |> List.to_tuple()

  # Maximum byte value that avoids modulo bias: largest multiple of 62 that fits in a byte.
  @max_unbiased 247

  # Generate enough bytes upfront to account for rejection sampling (~3% rejection rate).
  @batch_size 48

  @spec generate() ::
          {raw_token :: String.t(), key_hash :: String.t(), key_prefix :: String.t()}
  def generate do
    random_part = random_base62(@random_chars)
    raw_token = @prefix <> random_part
    key_hash = hash(raw_token)
    key_prefix = String.slice(raw_token, 0, 8)
    {raw_token, key_hash, key_prefix}
  end

  @spec hash(String.t()) :: String.t()
  def hash(raw_token) do
    :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)
  end

  defp random_base62(count) do
    :crypto.strong_rand_bytes(@batch_size)
    |> :binary.bin_to_list()
    |> collect_chars(count, [])
  end

  defp collect_chars(_bytes, 0, acc) do
    acc |> Enum.reverse() |> List.to_string()
  end

  defp collect_chars([], remaining, acc) do
    :crypto.strong_rand_bytes(@batch_size)
    |> :binary.bin_to_list()
    |> collect_chars(remaining, acc)
  end

  defp collect_chars([byte | rest], remaining, acc) when byte <= @max_unbiased do
    char = elem(@base62_alphabet, rem(byte, 62))
    collect_chars(rest, remaining - 1, [char | acc])
  end

  defp collect_chars([_byte | rest], remaining, acc) do
    collect_chars(rest, remaining, acc)
  end
end
