defmodule VintageNet.Persistence.FlatFile do
  @behaviour VintageNet.Persistence

  @moduledoc """
  Save and load configurations from flat files
  """

  @impl true
  def save(ifname, config) do
    persistence_dir = persistence_dir()

    File.mkdir_p!(persistence_dir)

    Path.join(persistence_dir, ifname)
    |> File.write(:erlang.term_to_binary(config))
  end

  @impl true
  def load(ifname) do
    path = Path.join(persistence_dir(), ifname)

    case File.read(path) do
      {:ok, contents} -> non_raising_binary_to_term(contents)
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
      {:ok, files} -> files
      _other -> []
    end
  end

  defp persistence_dir() do
    Application.get_env(:vintage_net, :persistence_dir)
  end

  defp non_raising_binary_to_term(bin) do
    try do
      {:ok, :erlang.binary_to_term(bin)}
    catch
      _, _ -> {:error, :corrupt}
    end
  end
end
