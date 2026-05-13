# SPDX-FileCopyrightText: 2020 Frank Hunleth
# SPDX-FileCopyrightText: 2020 Jon Carstens
# SPDX-FileCopyrightText: 2022 Jason Axelson
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNet.Info do
  @moduledoc false

  alias VintageNet.PowerManager.PMControl

  @label_width 11

  @summary_keys [:ifname, :conn, :age, :type, :address, :notes]

  @summary_headers %{
    ifname: "IFNAME",
    conn: "CONN",
    age: "AGE",
    type: "TYPE",
    address: "ADDRESS",
    notes: "NOTES"
  }

  @doc """
  Print the current network status.

  `info()` prints a one-row-per-interface summary. `info("eth0")` prints a
  detailed view for one interface.
  """
  @spec info() :: :ok
  def info(), do: info([])

  @spec info(VintageNet.info_options() | VintageNet.ifname()) :: :ok
  def info(opts) when is_list(opts) do
    info_as_ansidata(opts) |> IO.ANSI.format() |> IO.puts()
  end

  def info(ifname) when is_binary(ifname), do: info(ifname, [])

  @spec info(VintageNet.ifname(), VintageNet.info_options()) :: :ok
  def info(ifname, opts) when is_binary(ifname) and is_list(opts) do
    info_as_ansidata(ifname, opts) |> IO.ANSI.format() |> IO.puts()
  end

  @doc """
  Format the summary view as ANSI data.
  """
  @spec info_as_ansidata() :: IO.ANSI.ansidata()
  def info_as_ansidata(), do: info_as_ansidata([])

  @spec info_as_ansidata(VintageNet.info_options() | VintageNet.ifname()) :: IO.ANSI.ansidata()
  def info_as_ansidata(opts) when is_list(opts) do
    case vintage_net_app_info() do
      {:ok, _version} -> summary_ansidata(opts)
      {:error, text} -> text
    end
  end

  def info_as_ansidata(ifname) when is_binary(ifname), do: info_as_ansidata(ifname, [])

  @spec info_as_ansidata(VintageNet.ifname(), VintageNet.info_options()) :: IO.ANSI.ansidata()
  def info_as_ansidata(ifname, opts) when is_binary(ifname) and is_list(opts) do
    case vintage_net_app_info() do
      {:ok, _version} -> detail_ansidata(ifname, opts)
      {:error, text} -> text
    end
  end

  # ---- Summary view ----

  defp summary_ansidata(opts) do
    ifnames = interfaces_to_show()
    available = VintageNet.get(["available_interfaces"]) || []
    primary = List.first(available)
    name_servers = VintageNet.get(["name_servers"]) || []
    version = Application.spec(:vintage_net)[:vsn] || ~c"?"

    [
      banner_line(version, hostname(), primary, name_servers),
      summary_table(ifnames, primary),
      "\n",
      summary_footer(ifnames, Keyword.get(opts, :verbose, false))
    ]
  end

  defp banner_line(version, hostname, primary, name_servers) do
    [
      "VintageNet v",
      to_string(version),
      "\nhost: ",
      hostname,
      " | primary: ",
      primary_text(primary),
      " | DNS: ",
      dns_text(name_servers),
      "\n\n"
    ]
  end

  defp primary_text(nil), do: "none"
  defp primary_text(ifname), do: [:bright, ifname, :reset]

  defp dns_text([]), do: "none"

  defp dns_text(servers) do
    servers
    |> Enum.map(fn %{address: address} -> VintageNet.IP.ip_to_string(address) end)
    |> Enum.intersperse(", ")
  end

  defp hostname() do
    case :inet.gethostname() do
      {:ok, name} -> to_string(name)
      _ -> "unknown"
    end
  end

  defp summary_table([], _primary), do: "No interfaces\n"

  defp summary_table(ifnames, primary) do
    rows = Enum.map(ifnames, &interface_row(&1, primary))

    Tablet.render(rows,
      keys: @summary_keys,
      formatter: &summary_formatter/2
    )
  end

  defp summary_formatter(:__header__, key), do: {:ok, Map.fetch!(@summary_headers, key)}
  defp summary_formatter(_, _), do: :default

  defp interface_row(ifname, primary) do
    type = VintageNet.get(["interface", ifname, "type"])

    %{
      ifname: if_cell(ifname, ifname == primary),
      conn: conn_cell(ifname),
      age: age_cell(ifname),
      type: type_abbreviation(type),
      address: address_cell(ifname),
      notes: notes_cell(ifname, type)
    }
  end

  defp if_cell(ifname, true), do: [:bright, ifname, :reset]
  defp if_cell(ifname, false), do: ifname

  defp conn_cell(ifname) do
    case VintageNet.get(["interface", ifname, "connection"]) do
      :internet -> [:green, "internet", :reset]
      :lan -> [:yellow, "lan", :reset]
      :disconnected -> [:red, "offline", :reset]
      nil -> "-"
      other -> to_string(other)
    end
  end

  defp age_cell(ifname) do
    case PropertyTable.fetch_with_timestamp(VintageNet, ["interface", ifname, "connection"]) do
      {:ok, _value, ts} -> friendly_time(System.monotonic_time() - ts)
      :error -> "-"
    end
  end

  defp type_abbreviation(nil), do: "?"
  defp type_abbreviation(VintageNet.Technology.Null), do: "Null"

  defp type_abbreviation(type) do
    name = inspect(type)

    if String.starts_with?(name, "VintageNet") do
      name |> String.trim_leading("VintageNet")
    else
      name
    end
  end

  defp address_cell(ifname) do
    addresses = VintageNet.get(["interface", ifname, "addresses"]) || []
    ipv4 = pick_ipv4(addresses)
    ipv6 = pick_global_ipv6(addresses)

    case {ipv4, ipv6} do
      {nil, nil} -> "-"
      {v4, nil} -> v4
      {nil, v6} -> v6
      {v4, v6} -> v4 <> "\n" <> v6
    end
  end

  defp pick_ipv4(addresses) do
    Enum.find_value(addresses, fn
      %{family: :inet, address: a, prefix_length: b} -> VintageNet.IP.cidr_to_string(a, b)
      _ -> nil
    end)
  end

  defp pick_global_ipv6(addresses) do
    Enum.find_value(addresses, fn
      %{family: :inet6, scope: :universe, address: a, prefix_length: b} ->
        VintageNet.IP.cidr_to_string(a, b)

      _ ->
        nil
    end)
  end

  defp notes_cell(ifname, type) do
    if wifi_type?(type), do: wifi_notes(ifname), else: ""
  end

  defp wifi_type?(nil), do: false
  defp wifi_type?(type), do: inspect(type) |> String.contains?("WiFi")

  defp wifi_notes(ifname) do
    with config when is_map(config) <- VintageNet.get_configuration(ifname),
         %{vintage_net_wifi: %{networks: [first | _]}} <- config,
         ssid when is_binary(ssid) <- Map.get(first, :ssid) do
      "SSID \"#{ssid}\""
    else
      _ -> ""
    end
  end

  defp summary_footer([], _verbose?), do: []

  defp summary_footer(_ifnames, verbose?) do
    base = [
      :faint,
      "VintageNet.info(\"<ifname>\") for one interface in detail\n",
      :reset
    ]

    if verbose? do
      base
    else
      base ++
        [
          :faint,
          "VintageNet.info(verbose: true) to include configurations\n",
          :reset
        ]
    end
  end

  # ---- Detail view ----

  defp detail_ansidata(ifname, opts) do
    case VintageNet.get(["interface", ifname, "type"]) do
      nil ->
        ["Interface ", :bright, ifname, :reset, " is not configured.\n"]

      type ->
        verbose? = Keyword.get(opts, :verbose, false)

        if VintageNet.get(["interface", ifname, "present"]) do
          [
            detail_header(ifname, type),
            format_power_management(ifname),
            format_addresses(ifname),
            format_mac(ifname),
            format_hw_path(ifname),
            format_config(ifname, opts, verbose?),
            "\n"
          ]
        else
          [
            "Interface ",
            :bright,
            ifname,
            :reset,
            "  ",
            type_abbreviation(type),
            "  ",
            :light_red,
            "not present",
            :reset,
            "\n",
            format_power_management(ifname),
            format_config(ifname, opts, verbose?),
            "\n"
          ]
        end
    end
  end

  defp detail_header(ifname, type) do
    [
      "Interface ",
      :bright,
      ifname,
      :reset,
      "  ",
      type_abbreviation(type),
      "  ",
      format_state(ifname),
      " / ",
      format_connection(ifname),
      "\n"
    ]
  end

  defp format_state(ifname) do
    format_property_with_age(ifname, "state", &state_color/1)
  end

  defp format_connection(ifname) do
    format_property_with_age(ifname, "connection", &connection_color/1)
  end

  defp format_property_with_age(ifname, property, color_fn) do
    case PropertyTable.fetch_with_timestamp(VintageNet, ["interface", ifname, property]) do
      {:ok, value, ts} ->
        age = friendly_time(System.monotonic_time() - ts)
        [wrap(color_fn.(value), inspect(value)), " (", age, ")"]

      :error ->
        "nil"
    end
  end

  defp wrap(nil, content), do: content
  defp wrap(style, content), do: [style, content, :reset]

  defp state_color(:configured), do: :green
  defp state_color(:configuring), do: :yellow
  defp state_color(:retrying), do: :yellow
  defp state_color(_), do: :red

  defp connection_color(:internet), do: :green
  defp connection_color(:lan), do: :yellow
  defp connection_color(:disconnected), do: :red
  defp connection_color(_), do: nil

  defp format_addresses(ifname) do
    case VintageNet.get(["interface", ifname, "addresses"]) do
      nil -> []
      [] -> []
      addresses -> [label("Addresses"), pretty_addresses(addresses), "\n"]
    end
  end

  defp format_mac(ifname) do
    case VintageNet.get(["interface", ifname, "mac_address"]) do
      nil -> []
      "" -> []
      mac -> [label("MAC"), mac, "\n"]
    end
  end

  defp format_hw_path(ifname) do
    case VintageNet.get(["interface", ifname, "hw_path"]) do
      nil -> []
      "" -> []
      path -> [label("HW path"), path, "\n"]
    end
  end

  defp label(text), do: ["  ", String.pad_trailing(text <> ":", @label_width - 2)]

  defp format_config(_ifname, _opts, false), do: []

  defp format_config(ifname, opts, true) do
    ["  Configuration:\n", format_config_body(ifname, "    ", opts)]
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
        {:ok, Application.spec(:vintage_net)[:vsn]}
    end
  end

  defp format_config_body(ifname, prefix, opts) do
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
              :password,
              :sae_password,
              :private_key,
              :preshared_key
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

  defp format_power_management(ifname) do
    case PMControl.info(ifname) do
      {:ok, info} -> [label("Power"), info.pm_info, "\n"]
      _ -> []
    end
  end

  defp interfaces_to_show() do
    type = VintageNet.match(["interface", :_, "type"])

    for {[_interface, ifname, _type], _value} <- type do
      ifname
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

  defp pretty_address(other), do: inspect(other)

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
