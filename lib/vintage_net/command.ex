defmodule VintageNet.Command do
  @moduledoc false

  @doc """
  System.cmd wrapper to force paths

  This helper function updates calls to `System.cmd/3` to force them to use the
  PATHs configured on VintageNet for resolving where executables are.

  It has one major difference in API - if a command does not exist, an error
  exit status is returned with a message. `System.cmd/3` raises in this
  situation. This means that the caller needs to check the exit status if they
  care.
  """
  @spec cmd(Path.t(), [binary()], keyword()) ::
          {Collectable.t(), exit_status :: non_neg_integer()}
  def cmd(command, args, opts \\ []) when is_binary(command) do
    with {:ok, command_path} <- find_executable(command) do
      new_opts = force_path_env(opts)
      System.cmd(command_path, args, new_opts)
    end
  end

  @doc """
  Muontrap.cmd wrapper to force paths and options

  This is similar to `cmd/3`, but it also adds common Muontrap options. It is
  intended for long running commands or commands that may hang.
  """
  @spec muon_cmd(Path.t(), [binary()], keyword()) ::
          {Collectable.t(), exit_status :: non_neg_integer()}
  def muon_cmd(command, args, opts \\ []) when is_binary(command) do
    with {:ok, command_path} <- find_executable(command) do
      new_opts = opts |> force_path_env() |> add_muon_options()
      MuonTrap.cmd(command_path, args, new_opts)
    end
  end

  @doc """
  Add common options for MuonTrap
  """
  @spec add_muon_options(keyword()) :: keyword()
  def add_muon_options(opts) do
    Keyword.merge(
      opts,
      Application.get_env(:vintage_net, :muontrap_options)
    )
  end

  defp find_executable("/" <> _ = path) do
    # User supplied the absolute path so
    # just check that it exists
    if File.exists?(path) do
      {:ok, path}
    else
      {"'#{path}' not found", 256}
    end
  end

  # Note that error return value has to be compatible with System.cmd
  defp find_executable(command) do
    paths = String.split(path_env(), ":")

    path = paths |> Enum.map(&Path.join(&1, command)) |> Enum.find(&File.exists?/1)

    if path do
      {:ok, path}
    else
      {"'#{command}' not found in PATH='#{path_env()}'", 256}
    end
  end

  defp force_path_env(opts) do
    original_env = Keyword.get(opts, :env, [])

    new_env = [{"PATH", path_env()} | List.keydelete(original_env, "PATH", 0)]

    Keyword.put(opts, :env, new_env)
  end

  defp path_env() do
    Application.get_env(:vintage_net, :path)
  end
end
