defmodule VintageNet.Info do
  @moduledoc false

  @doc """
  Print the current network status
  """
  @spec info([VintageNet.info_options()]) :: :ok
  def info(opts \\ []) do
    case version() do
      :not_loaded ->
        IO.puts("VintageNet hasn't been loaded yet. Try again soon.")

      version ->
        IO.write(["VintageNet ", version, "\n\n"])

        do_info(opts)
    end
  end

  defp do_info(opts) do
    IO.write("""
    All interfaces:       #{inspect(VintageNet.all_interfaces())}
    Available interfaces: #{inspect(VintageNet.get(["available_interfaces"]))}
    """)

    ifnames = VintageNet.configured_interfaces()
    ip_addresses = ip_address_map()

    if ifnames == [] do
      IO.puts("\nNo configured interfaces")
    else
      ifnames
      |> Enum.map(fn ifname ->
        [
          "\nInterface ",
          ifname,
          "\n",
          format_if_attribute(ifname, "type", "Type"),
          format_if_attribute(ifname, "present", "Present"),
          format_if_attribute(ifname, "state", "State", true),
          format_if_attribute(ifname, "connection", "Connection", true),
          "  Addresses: ",
          inspect(Map.get(ip_addresses, ifname, [])),
          "\n",
          "  Configuration:\n",
          format_config(ifname, "    ", opts)
        ]
      end)
      |> IO.puts()
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

  defp format_if_attribute(ifname, name, print_name, print_since? \\ false) do
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
              friendly_time(:erlang.monotonic_time() - timestamp),
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

  @doc """
  Return a map of network interfaces to the list of IP addresses on them
  """
  @spec ip_address_map() :: %{VintageNet.ifname() => [String.t()]}
  def ip_address_map() do
    case :inet.getifaddrs() do
      {:ok, addresses} ->
        ifaddrs_to_address_map(addresses)

      _error ->
        %{}
    end
  end

  @doc """
  Convert the result of :inet.getifaddrs/0 to a ifname->addresses map
  """
  @spec ifaddrs_to_address_map([{charlist(), keyword()}]) ::
          %{VintageNet.ifname() => [String.t()]}
  def ifaddrs_to_address_map(addresses) do
    Enum.reduce(addresses, %{}, &process_one_interface/2)
  end

  defp process_one_interface({ifname_cl, attributes}, if_map) do
    Map.put(if_map, to_string(ifname_cl), process_attributes(attributes))
  end

  defp process_attributes(attributes) do
    process_attributes(attributes, nil, [])
  end

  defp process_attributes([], nil = _last_address, accumulator), do: accumulator

  defp process_attributes([], last_address, accumulator) do
    [VintageNet.IP.ip_to_string(last_address) | accumulator]
  end

  defp process_attributes([{:addr, address} | rest], nil = _last_address, accumulator) do
    process_attributes(rest, address, accumulator)
  end

  defp process_attributes([{:addr, address} | rest], last_address, accumulator) do
    process_attributes(rest, address, [VintageNet.IP.ip_to_string(last_address) | accumulator])
  end

  defp process_attributes([{:netmask, mask} | rest], last_address, accumulator)
       when last_address != nil do
    {:ok, bits} = VintageNet.IP.subnet_mask_to_prefix_length(mask)

    process_attributes(rest, nil, [VintageNet.IP.cidr_to_string(last_address, bits) | accumulator])
  end

  defp process_attributes([_other | rest], last_address, accumulator) when last_address != nil do
    process_attributes(rest, nil, [VintageNet.IP.ip_to_string(last_address) | accumulator])
  end

  defp process_attributes([_other | rest], nil, accumulator) do
    process_attributes(rest, nil, accumulator)
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
