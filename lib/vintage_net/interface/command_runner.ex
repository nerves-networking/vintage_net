defmodule VintageNet.Interface.CommandRunner do
  alias VintageNet.Interface.RawConfig

  require Logger

  @doc """
  Run a list of commands
  """
  @spec run([RawConfig.command()] | RawConfig.command()) :: :ok | {:error, any()}
  def run([]), do: :ok

  def run([command | rest]) do
    case run(command) do
      :ok ->
        run(rest)

      error ->
        error
    end
  end

  def run({:run, command, args}) do
    case MuonTrap.cmd(command, args) do
      {_, 0} ->
        :ok

      {message, _not_zero} ->
        Logger.error("Error running #{command}, #{inspect(args)}: #{message}")
        {:error, message}
    end
  end

  @doc """
  """
  @spec create_files([RawConfig.file_contents()]) :: :ok
  def create_files(file_contents) do
    Enum.each(file_contents, &create_and_write_file/1)
  end

  defp create_and_write_file({path, content}) do
    dir = Path.dirname(path)
    File.exists?(dir) || File.mkdir_p!(dir)

    File.write!(path, content)
  end

  @doc """
  """
  @spec remove_files([RawConfig.file_contents()]) :: :ok
  def remove_files(file_contents) do
    Enum.each(file_contents, &remove_file/1)
  end

  defp remove_file({path, _content}) do
    # Ignore errors
    _ = File.rm(path)
  end
end
