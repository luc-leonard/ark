defmodule Ark.Accounts.TokenGenerator do
  @moduledoc false

  @prefix "ark_"
  @random_bytes 32
  @base62_alphabet Enum.concat([?0..?9, ?A..?Z, ?a..?z])

  @spec generate() ::
          {raw_token :: String.t(), key_hash :: String.t(), key_prefix :: String.t()}
  def generate do
    random_part = random_base62(@random_bytes)
    raw_token = @prefix <> random_part
    key_hash = hash(raw_token)
    key_prefix = String.slice(raw_token, 0, 8)
    {raw_token, key_hash, key_prefix}
  end

  @spec hash(String.t()) :: String.t()
  def hash(raw_token) do
    :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)
  end

  # Maximum byte value that avoids modulo bias: largest multiple of 62 that fits in a byte.
  @max_unbiased 247

  defp random_base62(count) do
    do_random_base62(count, [])
    |> List.to_string()
  end

  defp do_random_base62(0, acc), do: Enum.reverse(acc)

  defp do_random_base62(remaining, acc) do
    <<byte>> = :crypto.strong_rand_bytes(1)

    if byte <= @max_unbiased do
      char = Enum.at(@base62_alphabet, rem(byte, 62))
      do_random_base62(remaining - 1, [char | acc])
    else
      # Reject biased values and retry
      do_random_base62(remaining, acc)
    end
  end
end
