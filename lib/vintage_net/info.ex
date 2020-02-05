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

    if ifnames == [] do
      IO.puts("\nNo configured interfaces")
    else
      Enum.each(ifnames, fn ifname ->
        IO.puts("\nInterface #{ifname}")
        print_if_attribute(ifname, "type", "Type")
        print_if_attribute(ifname, "present", "Present")
        print_if_attribute(ifname, "state", "State")
        print_if_attribute(ifname, "connection", "Connection")
        IO.puts("  Configuration:")
        print_config(ifname, "    ", opts)
      end)
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

  defp print_config(ifname, prefix, opts) do
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
    |> Enum.map(fn s -> prefix <> s end)
    |> Enum.intersperse("\n")
    |> IO.puts()
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

  defp print_if_attribute(ifname, name, print_name) do
    value = VintageNet.get(["interface", ifname, name])
    IO.puts("  #{print_name}: #{inspect(value)}")
  end
end
