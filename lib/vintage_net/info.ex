# SPDX-FileCopyrightText: 2020 Frank Hunleth
# SPDX-FileCopyrightText: 2020 Jon Carstens
# SPDX-FileCopyrightText: 2022 Jason Axelson
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.Info do
  @moduledoc false

  alias VintageNet.PowerManager.PMControl

  @doc """
  Print the current network status
  """
  @spec info(VintageNet.info_options()) :: :ok
  def info(opts \\ []) do
    info_as_ansidata(opts)
    |> IO.ANSI.format()
    |> IO.puts()
  end

  @doc """
  Format the information as ANSI data
  """
  @spec info_as_ansidata(VintageNet.info_options()) :: IO.ANSI.ansidata()
  def info_as_ansidata(opts \\ []) do
    case vintage_net_app_info() do
      {:ok, text} ->
        ifnames = interfaces_to_show()
        [Tablet.render(global_info(), name: text), format_interfaces(ifnames, opts)]

      {:error, text} ->
        text
    end
  end

  defp global_info() do
    [
      %{key: "All interfaces", value: inspect(VintageNet.all_interfaces())},
      %{key: "Available interfaces", value: inspect(VintageNet.get(["available_interfaces"]))}
    ]
  end

  defp format_interfaces([], _opts) do
    "\nNo interfaces\n"
  end

  defp format_interfaces(ifnames, opts) do
    Enum.map(ifnames, &interface_table(&1, opts))
  end

  defp interfaces_to_show() do
    type = VintageNet.match(["interface", :_, "type"])

    for {[_interface, ifname, _type], _value} <- type do
      ifname
    end
  end

  defp interface_table(ifname, _opts) do
    data =
      if VintageNet.get(["interface", ifname, "present"]) do
        [
          format_if_attribute(ifname, "type", "Type"),
          format_power_management(ifname),
          format_if_attribute(ifname, "present", "Present"),
          format_if_attribute(ifname, "state", "State", true),
          format_if_attribute(ifname, "connection", "Connection", true),
          format_addresses(ifname),
          format_if_attribute(ifname, "mac_address", "MAC Address")
        ]
      else
        [
          format_if_attribute(ifname, "type", "Type"),
          format_power_management(ifname),
          %{key: "Present", value: false}
        ]
      end

    Tablet.render(data, name: "Interface #{ifname}")
  end

  defp loaded?(app) do
    Application.loaded_applications()
    |> List.keyfind(app, 0)
    |> case do
      {^app, _description, _version} -> true
      _ -> false
    end
  end

  defp started?(app) do
    Application.started_applications()
    |> List.keyfind(app, 0)
    |> case do
      {^app, _description, _version} -> true
      _ -> false
    end
  end

  defp vintage_net_app_info() do
    cond do
      not loaded?(:vintage_net) ->
        {:error, "VintageNet hasn't been loaded. If the system just booted, try again shortly."}

      not started?(:vintage_net) ->
        {:error,
         "VintageNet loaded, but not started. Check the log to see if an error stopped the :vintage_net application."}

      true ->
        {:ok, "VintageNet #{Application.spec(:vintage_net)[:vsn]}"}
    end
  end

  defp format_if_attribute(ifname, name, print_name, print_since? \\ false) do
    case PropertyTable.fetch_with_timestamp(VintageNet, ["interface", ifname, name]) do
      {:ok, value, timestamp} ->
        %{
          key: print_name,
          value: [
            inspect(value),
            if(print_since?,
              do: [
                " (",
                friendly_time(System.monotonic_time() - timestamp),
                ")"
              ],
              else: ""
            )
          ]
        }

      :error ->
        # Mirror previous behavior (i.e., print nil for unset attributes)
        %{key: print_name, value: "nil"}
    end
  end

  defp format_power_management(ifname) do
    case PMControl.info(ifname) do
      {:ok, info} ->
        %{key: "Power", value: info.pm_info}

      _anything_else ->
        %{key: "Power", value: "N/A"}
    end
  end

  defp format_addresses(ifname) do
    case VintageNet.get(["interface", ifname, "addresses"]) do
      nil -> %{key: "Addresses", value: "None"}
      [] -> %{key: "Addresses", value: "None"}
      addresses -> %{key: "Addresses", value: pretty_addresses(addresses)}
    end
  end

  defp pretty_addresses(addresses) do
    addresses
    |> Enum.map(&pretty_address/1)
    |> Enum.intersperse("\n")
  end

  defp pretty_address(%{address: address, prefix_length: bits}) do
    VintageNet.IP.cidr_to_string(address, bits)
  end

  defp pretty_address(other) do
    inspect(other)
  end

  @spec friendly_time(integer()) :: iodata()
  def friendly_time(delta_ns) when is_integer(delta_ns) do
    cond do
      delta_ns < 1000 -> "#{delta_ns} ns"
      delta_ns < 1_000_000 -> :io_lib.format(~c"~.1f μs", [delta_ns / 1000])
      delta_ns < 1_000_000_000 -> :io_lib.format(~c"~.1f ms", [delta_ns / 1_000_000])
      delta_ns < 60_000_000_000 -> :io_lib.format(~c"~.1f s", [delta_ns / 1_000_000_000])
      true -> format_seconds(div(delta_ns, 1_000_000_000))
    end
  end

  defp format_seconds(seconds) do
    days = seconds |> div(86400)
    h = seconds |> div(3600) |> rem(24)
    m = seconds |> div(60) |> rem(60)
    s = seconds |> rem(60)

    [
      if(days > 0, do: [Integer.to_string(days), " days, "], else: []),
      Integer.to_string(h),
      ":",
      zero_pad(m),
      ":",
      zero_pad(s)
    ]
  end

  defp zero_pad(x), do: String.pad_leading(Integer.to_string(x), 2, "0")
end
