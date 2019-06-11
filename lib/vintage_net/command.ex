defmodule VintageNet.Command do
  @moduledoc false

  @spec cmd(atom(), [binary()], keyword()) ::
          {Collectable.t(), exit_status :: non_neg_integer()}
  def cmd(command, args, opts \\ []) do
    new_opts = force_path_env(opts)

    case Application.get_env(:vintage_net, command) do
      nil ->
        raise "Unexpected command #{command}"

      path ->
        System.cmd(path, args, new_opts)
    end
  end

  @spec muon_cmd(binary(), [binary()], keyword()) ::
          {Collectable.t(), exit_status :: non_neg_integer()}
  def muon_cmd(command, args, opts \\ []) do
    new_opts = force_path_env(opts)

    MuonTrap.cmd(command, args, new_opts)
  end

  defp force_path_env(opts) do
    original_env = Keyword.get(opts, :env, [])

    new_env = [path_env() | List.keydelete(original_env, "PATH", 0)]

    Keyword.put(opts, :env, new_env)
  end

  defp path_env() do
    {"PATH", Application.get_env(:vintage_net, :path)}
  end
end
