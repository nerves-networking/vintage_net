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
  alias VintageNet.Command
  alias VintageNet.Interface.{OutputLogger, RawConfig}

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
    case Command.muon_cmd(command, args,
           stderr_to_stdout: true,
           into: OutputLogger.new(command <> ":")
         ) do
      {_, 0} ->
        :ok

      {_, not_zero} ->
        _ = Logger.error("Nonzero exit from #{command}, #{inspect(args)}: #{not_zero}")
        {:error, :non_zero_exit}
    end
  end

  @doc """
  Run a command and ignore its exit code
  """
  def run({:run_ignore_errors, command, args}) do
    _ =
      Command.muon_cmd(command, args,
        stderr_to_stdout: true,
        into: OutputLogger.new(command <> ":")
      )

    :ok
  end

  @doc """
  Call a function

  In general, prefer the `module, function_name, args` form since it's easier to
  check in unit tests.

  Functions must return `:ok` or `{:error, reason}`.
  """
  def run({:fun, module, function_name, args}) do
    apply(module, function_name, args)
  end

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
