# SPDX-FileCopyrightText: 2026 Cocoa Xu
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.PredictableInterfaceName.Matcher do
  @moduledoc """
  Match interfaces against predictable ifname rules

  A rule matches when it has at least one of these keys and all of them match:

  * `:hw_path` - the interface's `hw_path`
  * `:kernels` - the name of the device or a parent, e.g. `"0000:23:00.0"`
  * `:drivers` - the driver of the device or a parent
  * `:mac` - the MAC address

  Each takes a pattern or a list of them. A pattern is a udev style glob with
  `*`, `?` and `|`, or a regex. Write regexes as `{:regex, "..."}` in
  `config.exs`.
  """

  @match_keys [:hw_path, :kernels, :drivers, :mac]

  @type device() :: %{
          hw_path: Path.t(),
          kernels: [String.t()],
          drivers: [String.t()],
          mac: String.t() | nil
        }

  @doc """
  Check whether an interface matches a rule

  Examples:

      iex> device = %{hw_path: "/devices/pci0000:00/0000:00:1c.4/0000:23:00.1", kernels: ["pci0000:00", "0000:00:1c.4", "0000:23:00.1"], drivers: ["ixgbe", "pcieport"], mac: "1c:86:0b:12:34:56"}
      iex> Matcher.matches?(%{ifname: "ethdev1", kernels: "0000:23:00.1", mac: "1c:86:0b:*|a0:10:a2:*"}, device)
      true
      iex> Matcher.matches?(%{ifname: "ethdev1", kernels: ["0000:0b:00.1", "0000:29:00.1"]}, device)
      false
      iex> Matcher.matches?(%{ifname: "wlan0", drivers: "mt7921e"}, device)
      false
  """
  @spec matches?(map(), device()) :: boolean()
  def matches?(rule, device) do
    keys = Map.take(rule, @match_keys)
    keys != %{} and Enum.all?(keys, fn {key, patterns} -> any_match?(patterns, device[key]) end)
  end

  defp any_match?(patterns, values) do
    patterns = List.wrap(patterns)

    values
    |> List.wrap()
    |> Enum.any?(fn value -> Enum.any?(patterns, &pattern_matches?(&1, value)) end)
  end

  defp pattern_matches?(%Regex{} = regex, value), do: Regex.match?(regex, value)

  defp pattern_matches?({:regex, source}, value),
    do: source |> Regex.compile!() |> Regex.match?(value)

  defp pattern_matches?(glob, value), do: glob |> glob_to_regex() |> Regex.match?(value)

  defp glob_to_regex(glob) do
    alternatives =
      glob
      |> String.split("|")
      |> Enum.map_join("|", fn alternative ->
        alternative
        |> Regex.escape()
        |> String.replace("\\*", ".*")
        |> String.replace("\\?", ".")
      end)

    Regex.compile!("\\A(?:#{alternatives})\\z")
  end

  @doc """
  Read an interface's attributes from sysfs
  """
  @spec device(VintageNet.ifname(), Path.t(), Path.t()) :: device()
  def device(ifname, hw_path, sysfs \\ "/sys") do
    %{
      hw_path: hw_path,
      kernels: hw_path |> Path.split() |> Enum.drop(2),
      drivers: drivers(sysfs, hw_path),
      mac: mac(Path.join([sysfs, "class/net", ifname, "address"]))
    }
  end

  defp drivers(sysfs, hw_path) do
    devices = Path.join(sysfs, "devices") <> "/"

    sysfs
    |> Path.join(hw_path)
    |> Stream.iterate(&Path.dirname/1)
    |> Enum.take_while(&String.starts_with?(&1, devices))
    |> Enum.flat_map(fn path ->
      case File.read_link(Path.join(path, "driver")) do
        {:ok, driver} -> [Path.basename(driver)]
        {:error, _} -> []
      end
    end)
  end

  defp mac(path) do
    case File.read(path) do
      {:ok, address} -> String.trim(address)
      {:error, _} -> nil
    end
  end
end
