defmodule VintageNet.Diagnostics.Kernel do
  @type config_value :: :built_in | :module | String.t()
  @type config_map :: %{String.t() => config_value()}

  @doc """
  Return the kernel configuration as a map

  Only enabled options are returned. Like in the kernel, the symbols are listed
  without the `CONFIG_` prefix.

  In order to use this function,
  the Linux kernel on the device needs to have `IKCONFIG=y` and `IKCONFIG_PROC=y` in
  the configuration. Otherwise `/proc/config.gz` doesn't exist.
  """
  @spec config(Path.t()) :: {:ok, config_map()} | {:error, File.posix()}
  def config(path \\ "/proc/config.gz") do
    with {:ok, fd} <- File.open(path, [:compressed]),
         {:ok, kv_pairs} <- read_all(fd, []) do
      _ = File.close(fd)
      {:ok, Map.new(kv_pairs)}
    end
  end

  defp read_all(fd, acc) do
    case IO.binread(fd, :line) do
      "CONFIG_" <> setting ->
        [k, v] = String.split(setting, "=", parts: 2)
        read_all(fd, [{k, option(v)} | acc])

      :eof ->
        {:ok, acc}

      {:error, _reason} = error ->
        error

      _other ->
        read_all(fd, acc)
    end
  end

  defp option("y" <> _rest), do: :built_in
  defp option("m" <> _rest), do: :module
  defp option(other), do: String.trim(other)
end
