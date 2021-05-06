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
    name_servers = Enum.reduce(entries, %{}, &add_name_servers/2)

    name_servers =
      Enum.reduce(additional_name_servers, name_servers, &add_name_server("global", &1, &2))

    [
      "# This file is managed by VintageNet. Do not edit.\n\n",
      Enum.map(domains, &domain_text/1),
      Enum.map(name_servers, &name_server_text/1)
    ]
  end

  defp domain_text({domain, ifnames}),
    do: ["search ", domain, " # From ", Enum.join(ifnames, ","), "\n"]

  defp name_server_text({server, ifnames}),
    do: ["nameserver ", IP.ip_to_string(server), " # From ", Enum.join(ifnames, ","), "\n"]

  defp add_domain({ifname, %{domain: domain}}, acc) when is_binary(domain) and domain != "" do
    Map.update(acc, domain, [ifname], fn ifnames -> [ifname | ifnames] end)
  end

  defp add_domain(_other, acc), do: acc

  defp add_name_servers({ifname, %{name_servers: servers}}, acc) do
    Enum.reduce(servers, acc, &add_name_server(ifname, &1, &2))
  end

  defp add_name_server(ifname, server, acc) do
    Map.update(acc, server, [ifname], fn ifnames -> [ifname | ifnames] end)
  end
end
