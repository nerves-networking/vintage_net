defmodule VintageNet.Resolver.ResolvConf do
  @moduledoc false
  alias VintageNet.IP

  # Convert name resolver configurations into
  # /etc/resolv.conf contents

  @typedoc "Name resolver settings for an interface"
  @type entry :: %{
          priority: integer(),
          domain: String.t(),
          name_servers: [:inet.ip_address()]
        }

  @typedoc "All entries"
  @type entry_map :: %{VintageNet.ifname() => entry()}
  @type additional_name_servers :: [:inet.ip_address()]

  @spec to_config(entry_map(), additional_name_servers) :: iolist()
  def to_config(entries, additional_name_servers) do
    domains = Enum.reduce(entries, %{}, &add_domain/2)
    name_servers = collect_name_servers(entries, additional_name_servers)

    [
      "# This file is managed by VintageNet. Do not edit.\n\n",
      Enum.map(domains, &domain_text/1),
      Enum.map(name_servers, &name_server_text/1)
    ]
  end

  defp domain_text({domain, ifnames}),
    do: ["search ", domain, " # From ", Enum.join(ifnames, ","), "\n"]

  defp name_server_text({server, ifnames}),
    do: ["nameserver ", server_ip(server), " # From ", Enum.join(ifnames, ","), "\n"]

  # Format the IP address with a port if it's nonstandard
  defp server_ip({server, port}) when port == 53, do: IP.ip_to_string(server)
  defp server_ip({server, port}), do: [IP.ip_to_string(server), ?:, Integer.to_string(port)]
  defp server_ip(server), do: IP.ip_to_string(server)

  defp add_domain({ifname, %{domain: domain}}, acc) when is_binary(domain) and domain != "" do
    Map.update(acc, domain, [ifname], fn ifnames -> ifnames ++ [ifname] end)
  end

  defp add_domain(_other, acc), do: acc

  defp collect_name_servers(entries, additional_name_servers) do
    # Return has the form [{name_server, [ifname]}]

    # Global name servers come first. If an interface supplies multiple
    # name servers, then they will be listed in order specified. Duplicates
    # are removed.

    # Collect all name servers in a list with their order and name
    global_servers =
      Enum.with_index(additional_name_servers, fn server, index ->
        {server, index - 100, "global"}
      end)

    if_servers = Enum.flat_map(entries, &entry_to_name_servers/1)

    all_name_servers = global_servers ++ if_servers

    # Merge duplicates
    ns_map = Enum.reduce(all_name_servers, %{}, &merge_name_servers/2)

    # Get the name servers back into a list and sort them
    ns_map
    |> Map.to_list()
    |> Enum.sort(fn {_, {index1, _}}, {_, {index2, _}} -> index1 < index2 end)
    |> Enum.map(fn {server, {_, ifnames}} -> {server, ifnames} end)
  end

  defp entry_to_name_servers({ifname, %{name_servers: servers}}) do
    # Return [{server, index, ifname}]
    servers
    |> Enum.with_index(fn server, index -> {server, index, ifname} end)
  end

  defp merge_name_servers({server, index, where}, acc) do
    Map.update(acc, server, {index, [where]}, fn {existing_index, list} ->
      {min(existing_index, index), list ++ [where]}
    end)
  end
end
