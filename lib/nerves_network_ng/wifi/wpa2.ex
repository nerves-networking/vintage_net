defmodule Nerves.NetworkNG.WiFi.WPA2 do
  @moduledoc """
  WPA2 preshared key calculations

  WPA2 doesn't use passphrases directly, but instead hashes them with the
  SSID and uses the result for the network key. The algorithm that runs
  the hash takes some time so it's useful to compute the PSK from the
  passphrase once rather than specifying it each time.
  """

  @typedoc "A WPA2 preshared key"
  @type psk :: <<_::512>>

  @doc """
  Convert a WiFi WPA2 passphrase into a PSK

  If a passphrase looks like a PSK, then it's assumed that it already is a PSK
  and is passed through.

  See IEEE Std 802.11i-2004 Appendix H.4 for the algorithm.
  """
  @spec to_psk(String.t(), psk() | String.t()) :: {:ok, psk()} | {:error, atom()}
  def to_psk(ssid, psk) when byte_size(psk) == 64 do
    with :ok <- psk_ok(psk),
         :ok <- ssid_ok(ssid) do
        {:ok, psk}
    end
  end

  def to_psk(ssid, passphrase) do
    with :ok <- password_ok(passphrase),
         :ok <- ssid_ok(ssid) do
      {:ok, compute_psk(ssid, passphrase)}
    end
  end

  defp compute_psk(ssid, passphrase) do
    result = f(ssid, passphrase, 4096, 1) <> f(ssid, passphrase, 4096, 2)
    <<result256::256, _::binary>> = result

    result256
    |> Integer.to_string(16)
    |> String.pad_leading(64, "0")
  end

  # F(P, S, c, i) = U1 xor U2 xor ... Uc
  # U1 = PRF(P, S || Int(i))
  # U2 = PRF(P, U1)
  # Uc = PRF(P, Uc-1)
  defp f(ssid, password, iterations, count) do
    digest = <<ssid::binary, count::integer-32>>
    digest1 = sha1_hmac(digest, password)

    iterate(digest1, digest1, password, iterations - 1)
  end

  defp iterate(acc, _previous_digest, _password, 0) do
    acc
  end

  defp iterate(acc, previous_digest, password, n) do
    digest = sha1_hmac(previous_digest, password)
    iterate(xor160(acc, digest), digest, password, n - 1)
  end

  defp xor160(<<a::160>>, <<b::160>>) do
    <<:erlang.bxor(a, b)::160>>
  end

  defp sha1_hmac(digest, password) do
    :crypto.hmac(:sha, password, digest)
  end

  defp password_ok(password) when byte_size(password) <= 63 do
    all_ascii(password)
  end

  defp password_ok(_password), do: {:error, :password_too_long}

  defp psk_ok(psk) when byte_size(psk) == 64 do
    all_hex_digits(psk)
  end

  defp ssid_ok(ssid) when byte_size(ssid) <= 32, do: :ok
  defp ssid_ok(_password), do: {:error, :ssid_too_long}

  defp all_ascii(<<c, rest::binary>>) when c >= 32 and c <= 126 do
    all_ascii(rest)
  end

  defp all_ascii(<<>>), do: :ok

  defp all_ascii(_other), do: {:error, :invalid_characters}

  defp all_hex_digits(<<c, rest::binary>>) when (c >= ?0 and c <= ?9) or (c >= ?a and c <= ?f) or (c >= ?A and c <= ?F) do
    all_hex_digits(rest)
  end
  defp all_hex_digits(<<>>), do: :ok

  defp all_hex_digits(_other), do: {:error, :invalid_characters}
end
