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

  defp random_base62(n_bytes) do
    :crypto.strong_rand_bytes(n_bytes)
    |> :binary.bin_to_list()
    |> Enum.map(fn byte -> Enum.at(@base62_alphabet, rem(byte, 62)) end)
    |> List.to_string()
  end
end
