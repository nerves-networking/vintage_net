defmodule VintageNet.InterfacesMonitor.HWPath do
  @moduledoc false

  @doc """
  Figure out the hardware path to the interface

  This returns Linux's view of the network interface's location
  in the system. There is an assumption that Linux does not change
  hardware layout representations between kernel versions.

  This is similar to `DEVPATH` when running `udevadm info` on
  a desktop Linux system. The difference is that this trims off
  the network interface part of the path. So in desktop Linux,
  you'd see:

  ```
  DEVPATH=/devices/platform/scb/fd580000.genet/net/eth0
  ```

  Whereas `query/1` would return:

  ```
  /devices/platform/scb/fd580000.genet
  ```

  The final part can be reattached if you know the `ifname`. Since
  Linux allows you to rename network interfaces, that last part of
  the `DEVPATH` can change without anything changing with the
  hardware. That's why it's left off of the path here.
  """
  @spec query(VintageNet.ifname()) :: Path.t()
  def query(ifname) do
    case File.read_link("/sys/class/net/" <> ifname) do
      {:ok, link_path} ->
        symlink_to_hw_path(link_path, ifname)

      {:error, _any} ->
        ""
    end
  end

  @doc """
  Compute the hardware path from Linux's network interface symlink
  """
  @spec symlink_to_hw_path(Path.t(), VintageNet.ifname()) :: Path.t()
  def symlink_to_hw_path(path, ifname) do
    path
    |> String.trim_leading("../..")
    |> String.trim_trailing("/net/" <> ifname)
  end
end
