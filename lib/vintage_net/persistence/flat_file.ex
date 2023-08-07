defmodule VintageNet.Persistence.FlatFile do
  @moduledoc """
  Save and load configurations from flat files
  """
  @behaviour VintageNet.Persistence

  # Version 1 persistence files have the following format:
  #
  # Byte offset      Description
  # 0                Version number - set to 1
  # 1-16             Initialization vector
  # 17-32            Authentication tag
  # 33-              Network config run through :erlang.term_to_binary and
  #                  encrypted with AES in GCM mode
  @version 1

  # Yes, I'm aware that we're using AES 128 GCM
  @aad "AES256GCM"

  @impl VintageNet.Persistence
  def save(ifname, config) do
    persistence_dir = persistence_dir()
    path = Path.join(persistence_dir, ifname)

    with :ok <- File.mkdir_p(persistence_dir) do
      File.write(path, serialize_config(config), [:sync])
    end
  end

  @impl VintageNet.Persistence
  def load(ifname) do
    path = Path.join(persistence_dir(), ifname)

    with {:ok, contents} <- File.read(path) do
      deserialize_config(contents)
    end
  end

  @impl VintageNet.Persistence
  def clear(ifname) do
    path = Path.join(persistence_dir(), ifname)

    if File.exists?(path), do: File.rm!(path)

    :ok
  end

  @impl VintageNet.Persistence
  def enumerate() do
    case File.ls(persistence_dir()) do
      {:ok, files} ->
        # Sorting the filenames is mostly for the unit tests, but it feels
        # good making this deterministic.
        Enum.sort(files)

      _other ->
        []
    end
  end

  defp serialize_config(config) do
    secret_key = good_secret_key()
    plaintext = :erlang.term_to_binary(config)
    iv = :crypto.strong_rand_bytes(16)
    {ciphertext, tag} = encrypt(secret_key, iv, plaintext)
    <<@version, iv::16-bytes, tag::16-bytes, ciphertext::binary>>
  end

  defp deserialize_config(<<@version, iv::16-bytes, tag::16-bytes, ciphertext::binary>>) do
    secret_key = good_secret_key()

    case decrypt(secret_key, iv, ciphertext, tag) do
      plaintext when is_binary(plaintext) ->
        non_raising_binary_to_term(plaintext)

      _error ->
        {:error, :decryption_failed}
    end
  end

  defp deserialize_config(_anything_else), do: {:error, :corrupt}

  if :erlang.system_info(:otp_release) == ~c"21" do
    # Remove when OTP 21 is no longer supported.
    defp encrypt(secret_key, iv, plaintext) do
      :crypto.block_encrypt(:aes_gcm, secret_key, iv, {@aad, plaintext, 16})
    end

    defp decrypt(secret_key, iv, ciphertext, tag) do
      :crypto.block_decrypt(:aes_gcm, secret_key, iv, {"AES256GCM", ciphertext, tag})
    end
  else
    defp encrypt(secret_key, iv, plaintext) do
      :crypto.crypto_one_time_aead(:aes_128_gcm, secret_key, iv, plaintext, @aad, 16, true)
    end

    defp decrypt(secret_key, iv, ciphertext, tag) do
      :crypto.crypto_one_time_aead(:aes_128_gcm, secret_key, iv, ciphertext, @aad, tag, false)
    end
  end

  defp non_raising_binary_to_term(bin) do
    {:ok, :erlang.binary_to_term(bin)}
  catch
    _, _ -> {:error, :corrupt}
  end

  defp persistence_dir() do
    Application.get_env(:vintage_net, :persistence_dir)
  end

  defp good_secret_key() do
    case secret_key() do
      key when is_binary(key) and byte_size(key) == 16 ->
        key

      _other ->
        raise RuntimeError, "Secret key for persisting network settings isn't a 16-byte binary"
    end
  end

  defp secret_key() do
    case Application.get_env(:vintage_net, :persistence_secret) do
      {m, f, args} ->
        apply(m, f, args)

      f when is_function(f, 0) ->
        f.()

      unhidden_key when is_binary(unhidden_key) and byte_size(unhidden_key) == 16 ->
        unhidden_key

      other ->
        raise RuntimeError,
              "Can't use #{inspect(other)} as a secret_key for persisting network settings."
    end
  end
end
