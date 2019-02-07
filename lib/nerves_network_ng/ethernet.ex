defmodule Nerves.NetworkNG.Ethernet do
  alias Nerves.NetworkNG

  defstruct iface: "eth0", address_family: :inet, address_method: :dhcp

  @doc """
  Make new Ethernet struct
  """
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  def config_file() do
    tmp_dir = NetworkNG.tmp_dir()
    Path.join(tmp_dir, "interfaces")
  end

  def to_config(%__MODULE__{
        iface: iface,
        address_family: address_family,
        address_method: address_method
      }) do
    """
    auto #{iface}
    iface #{iface} #{address_family} #{address_method}
    """
  end

  def write_config_file(ethernet) do
    config_contents = to_config(ethernet)
    :ok = NetworkNG.ensure_tmp_dir()

    config_file()
    |> File.write(config_contents)
  end

  def down(iface \\ "eth0") do
    case System.cmd("ifdown", ["-i", config_file(), iface], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, 1} -> {:error, error}
    end
  end

  def up(iface \\ "eth0") do
    case System.cmd("ifup", ["-i", config_file(), iface], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, 1} -> {:error, error}
    end
  end
end
