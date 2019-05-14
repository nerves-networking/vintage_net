defmodule VintageNet.Interface.CommandRunner do
  @moduledoc """
  The CommandRunner module runs commands specified in RawConfigs

  See the `RawConfig` documentation for where lists of commands
  are specified. The following commands are supported:

  * `{:run, command, args}` - Run a system command
  * `{:run_ignore_exit, command, args}` - Same as `:run`, but without the exit status check
  * `{:fun, fun}` - Run an function

  CommandRunner also implements RawConfig's file creation and
  cleanup logic.
  """
  require Logger
  alias VintageNet.Interface.RawConfig

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

  @doc """
  Run a command

  Non-zero exit status will return an error.
  """
  def run({:run, command, args}) do
    case MuonTrap.cmd(command, args) do
      {_, 0} ->
        :ok

      {message, _not_zero} ->
        _ = Logger.error("Error running #{command}, #{inspect(args)}: #{message}")
        {:error, message}
    end
  end

  @doc """
  Run a command and ignore its exit code
  """
  def run({:run_ignore_errors, command, args}) do
    _ = MuonTrap.cmd(command, args)
    :ok
  end

  @doc """
  Run an arbitrary function

  In general, try to avoid using this. VintageNet's unit test strategy is
  to verify configurations rather than verify the execution of the configurations.
  Functions can't be checked that they were created correctly.

  Functions must return `:ok` or `{:error, reason}`.
  """
  def run({:fun, fun}) do
    fun.()
  end

  @doc """
  Create a list of files
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
  Remove a list of files
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
