defmodule VintageNet.Resolver.ResolvConf do
  @moduledoc false

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

  @spec to_config(entry_map()) :: iolist()
  def to_config(entries) do
    domains = search_domains(entries)
    name_servers = all_name_servers(entries)

    [Enum.map(domains, &domain_text/1), Enum.map(name_servers, &name_server_text/1)]
  end

  defp domain_text(domain), do: ["search ", domain, "\n"]

  defp name_server_text(server), do: ["nameserver ", ntoa!(server), "\n"]

  defp all_name_servers(entries) do
    entries
    |> Enum.flat_map(&name_servers/1)
    |> Enum.uniq()
  end

  defp search_domains(entries) do
    entries
    |> Enum.map(&domain/1)
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()
  end

  defp domain({_ifname, %{domain: domain}}) when is_binary(domain) and domain != "",
    do: domain

  defp domain(_), do: nil

  defp name_servers({_ifname, %{name_servers: servers}}) do
    for server <- servers, do: server
  end

  defp name_servers(_), do: []

  defp ntoa!(ip) do
    case :inet.ntoa(ip) do
      {:error, _reason} ->
        raise ArgumentError, "Invalid IP: #{inspect(ip)}"

      result ->
        result
    end
  end
end
