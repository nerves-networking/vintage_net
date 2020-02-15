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
    [Enum.map(entries, &domain_text/1), Enum.map(entries, &nameserver_text/1)]
  end

  defp domain_text({_ifname, %{domain: domain}}) when is_binary(domain) and domain != "",
    do: ["search ", domain, "\n"]

  defp domain_text(_), do: []

  defp nameserver_text({_ifname, %{name_servers: servers}}) do
    for server <- servers, do: ["nameserver ", ntoa!(server), "\n"]
  end

  defp nameserver_text(_), do: []

  defp ntoa!(ip) do
    case :inet.ntoa(ip) do
      {:error, _reason} ->
        raise ArgumentError, "Invalid IP in state: #{inspect(ip)}"

      result ->
        result
    end
  end
end
