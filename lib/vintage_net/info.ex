defmodule VintageNet.Info do
  @moduledoc false

  alias VintageNet.PowerManager.PMControl

  @doc """
  Print the current network status
  """
  @spec info([VintageNet.info_options()]) :: :ok
  def info(opts \\ []) do
    case version() do
      :not_loaded ->
        IO.puts("VintageNet hasn't been loaded yet. Try again soon.")

      version ->
        ifnames = interfaces_to_show()

        IO.write([format_header(version), format_interfaces(ifnames, opts)])
    end
  end

  defp format_header(version) do
    """
    VintageNet #{version}

    All interfaces:       #{inspect(VintageNet.all_interfaces())}
    Available interfaces: #{inspect(VintageNet.get(["available_interfaces"]))}

    """
  end

  defp format_interfaces([], _opts) do
    "No interfaces"
  end

  defp format_interfaces(ifnames, opts) do
    Enum.map(ifnames, &format_interface(&1, opts))
  end

  defp interfaces_to_show() do
    type = VintageNet.match(["interface", :_, "type"])

    for {[_interface, ifname, _type], _value} <- type do
      ifname
    end
  end

  defp format_interface(ifname, opts) do
    if VintageNet.get(["interface", ifname, "present"]) do
      [
        "Interface ",
        ifname,
        "\n",
        format_if_attribute(ifname, "type", "Type"),
        format_power_management(ifname),
        format_if_attribute(ifname, "present", "Present"),
        format_if_attribute(ifname, "state", "State", true),
        format_if_attribute(ifname, "connection", "Connection", true),
        format_addresses(ifname),
        "  Configuration:\n",
        format_config(ifname, "    ", opts),
        "\n"
      ]
    else
      [
        "Interface ",
        ifname,
        "\n",
        format_if_attribute(ifname, "type", "Type"),
        format_power_management(ifname),
        "  Present: false\n",
        "  Configuration:\n",
        format_config(ifname, "    ", opts),
        "\n"
      ]
    end
  end

  defp version() do
    Application.loaded_applications()
    |> List.keyfind(:vintage_net, 0)
    |> case do
      {:vintage_net, _description, version} -> version
      _ -> :not_loaded
    end
  end

  defp format_config(ifname, prefix, opts) do
    configuration = VintageNet.get_configuration(ifname)

    sanitized =
      if Keyword.get(opts, :redact, true) do
        sanitize_configuration(configuration)
      else
        configuration
      end

    sanitized
    |> inspect(pretty: true, width: 80 - String.length(prefix))
    |> String.split("\n")
    |> Enum.map(fn s -> [prefix, s, "\n"] end)
  end

  defp sanitize_configuration(input) when is_map(input) do
    Map.new(input, &sanitize_configuration/1)
  end

  # redact sensitive data
  defp sanitize_configuration({key, _})
       when key in [
              :psk,
              :password
            ] do
    {key, "...."}
  end

  defp sanitize_configuration({key, data}) when is_map(data) do
    {key, sanitize_configuration(data)}
  end

  defp sanitize_configuration({key, data}) when is_list(data) do
    {key, sanitize_configuration(data)}
  end

  defp sanitize_configuration({key, value}) do
    {key, value}
  end

  defp sanitize_configuration(data) when is_list(data) do
    Enum.reduce(data, [], fn
      list_data, acc when is_list(list_data) ->
        acc ++ sanitize_configuration(list_data)

      other_data, acc ->
        acc ++ [sanitize_configuration(other_data)]
    end)
  end

  defp sanitize_configuration(data), do: data

  @doc false
  def format_if_attribute(ifname, name, print_name, print_since? \\ false) do
    case VintageNet.PropertyTable.fetch_with_timestamp(VintageNet, ["interface", ifname, name]) do
      {:ok, value, timestamp} ->
        [
          "  ",
          print_name,
          ": ",
          inspect(value),
          if(print_since?,
            do: [
              " (",
              friendly_time(System.monotonic_time() - timestamp),
              ")\n"
            ],
            else: "\n"
          )
        ]

      :error ->
        # Mirror previous behavior (i.e., print nil for unset attributes)
        ["  ", print_name, ": nil\n"]
    end
  end

  defp format_power_management(ifname) do
    case PMControl.info(ifname) do
      {:ok, info} ->
        ["  Power: ", info.pm_info, "\n"]

      _anything_else ->
        []
    end
  end

  defp format_addresses(ifname) do
    case VintageNet.get(["interface", ifname, "addresses"]) do
      nil -> []
      [] -> []
      addresses -> ["  Addresses: ", pretty_addresses(addresses), "\n"]
    end
  end

  defp pretty_addresses(addresses) do
    addresses
    |> Enum.map(&pretty_address/1)
    |> Enum.intersperse(", ")
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
      delta_ns < 1_000_000 -> :io_lib.format('~.1f μs', [delta_ns / 1000])
      delta_ns < 1_000_000_000 -> :io_lib.format('~.1f ms', [delta_ns / 1_000_000])
      delta_ns < 60_000_000_000 -> :io_lib.format('~.1f s', [delta_ns / 1_000_000_000])
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
