defmodule VintageNet.Persistence.FlatFile do
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
  @mode :aes_gcm
  @aad "AES256GCM"

  @moduledoc """
  Save and load configurations from flat files
  """

  @impl true
  def save(ifname, config) do
    persistence_dir = persistence_dir()

    File.mkdir_p!(persistence_dir)

    Path.join(persistence_dir, ifname)
    |> File.write(serialize_config(config), [:sync])
  end

  @impl true
  def load(ifname) do
    path = Path.join(persistence_dir(), ifname)

    case File.read(path) do
      {:ok, contents} -> deserialize_config(contents)
      error -> error
    end
  end

  @impl true
  def clear(ifname) do
    Path.join(persistence_dir(), ifname)
    |> File.rm!()
  end

  @impl true
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
    {ciphertext, tag} = :crypto.block_encrypt(@mode, secret_key, iv, {@aad, plaintext, 16})
    <<@version, iv::16-bytes, tag::16-bytes, ciphertext::binary>>
  end

  defp deserialize_config(<<@version, iv::16-bytes, tag::16-bytes, ciphertext::binary>>) do
    secret_key = good_secret_key()

    case :crypto.block_decrypt(:aes_gcm, secret_key, iv, {"AES256GCM", ciphertext, tag}) do
      :error ->
        {:error, :decryption_failed}

      plaintext ->
        non_raising_binary_to_term(plaintext)
    end
  end

  defp deserialize_config(_anything_else), do: {:error, :corrupt}

  defp non_raising_binary_to_term(bin) do
    try do
      {:ok, :erlang.binary_to_term(bin)}
    catch
      _, _ -> {:error, :corrupt}
    end
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
      {m, f, a} ->
        apply(m, f, a)

      f when is_function(f, 0) ->
        apply(f, [])

      unhidden_key when is_binary(unhidden_key) and byte_size(unhidden_key) == 16 ->
        unhidden_key

      other ->
        raise RuntimeError,
              "Can't use #{inspect(other)} as a secret_key for persisting network settings."
    end
  end
end
