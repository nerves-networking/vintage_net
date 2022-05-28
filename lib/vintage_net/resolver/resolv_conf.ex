defmodule VintageNet.Resolver.ResolvConf do
  @moduledoc """
  Utilities for creating resolv.conf file contents
  """
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
  @type name_server_info :: %{address: :inet.ip_address(), from: [:global | VintageNet.ifname()]}

  @doc """
  Convert the name server information to resolv.conf contents
  """
  @spec to_config(entry_map(), additional_name_servers()) :: iolist()
  def to_config(entries, additional_name_servers) do
    domains = Enum.reduce(entries, %{}, &add_domain/2)
    name_servers = to_name_server_list(entries, additional_name_servers)

    [
      "# This file is managed by VintageNet. Do not edit.\n\n",
      Enum.map(domains, &domain_text/1),
      Enum.map(name_servers, &name_server_text/1)
    ]
  end

  @spec to_name_server_list(entry_map(), additional_name_servers) :: [name_server_info()]
  def to_name_server_list(entries, additional_name_servers) do
    # This is trickier than it looks since we want the ordering of name
    # servers to be deterministic. Here are the rules:
    #
    # 1. No duplicates entries (interfaces can supply similar entries to this is a common case)
    # 2. Entries listed in the order supplied if possible. It's possible that
    #    that two interfaces specify the same entries in a different order, so don't try to fix that.
    # 3. Global entries are always first

    Enum.reduce(entries, %{}, &add_name_servers(&2, &1))
    |> add_name_servers({:global, %{name_servers: additional_name_servers}})
    |> Enum.map(&sort_ifname_lists/1)
    |> Enum.sort(&name_server_lte/2)
    |> Enum.map(fn {address, ifname_tuples} ->
      %{address: address, from: Enum.map(ifname_tuples, fn {ifname, _ix} -> ifname end)}
    end)
  end

  defp add_domain({ifname, %{domain: domain}}, acc) when is_binary(domain) and domain != "" do
    Map.update(acc, domain, [ifname], fn ifnames -> [ifname | ifnames] end)
  end

  defp add_domain(_other, acc), do: acc

  defp add_name_servers(name_servers, {ifname, %{name_servers: servers}}) do
    indexed_servers = Enum.with_index(servers)
    Enum.reduce(indexed_servers, name_servers, &add_name_server(ifname, &1, &2))
  end

  defp add_name_server(ifname, {server, index}, acc) do
    ifname_index = {ifname, index}
    Map.update(acc, server, [ifname_index], fn ifnames -> [ifname_index | ifnames] end)
  end

  defp sort_ifname_lists({ns, ifname_index_list}) do
    sorted_list = Enum.sort(ifname_index_list, &ifname_ix_compare/2)
    {ns, sorted_list}
  end

  defp ifname_ix_compare({ifname, ix1}, {ifname, ix2}), do: ix1 <= ix2
  defp ifname_ix_compare({:global, _ix1}, _not_global), do: true
  defp ifname_ix_compare(_not_global, {:global, _ix2}), do: false
  defp ifname_ix_compare({ifname1, _ix1}, {ifname2, _ix2}), do: ifname1 <= ifname2

  defp name_server_lte(
         {_ns1, ifname_index_list1} = a,
         {_ns2, ifname_index_list2} = b,
         ifname \\ :global
       ) do
    index1 = find_ifname_index(ifname_index_list1, ifname)
    index2 = find_ifname_index(ifname_index_list2, ifname)

    case {index1, index2} do
      {nil, nil} ->
        # The lists are sorted by this point so arbitrarily pick
        # the first one's list to choose the ifname to compare.
        # Note that the recursive call is guaranteed not to hit
        # this case again since index1 will be found.
        [{first_ifname, _index} | _] = ifname_index_list1
        name_server_lte(a, b, first_ifname)

      {nil, _not_nil} ->
        false

      {_not_nil, nil} ->
        true

      {_not_nil, _not_nil2} ->
        index1 <= index2
    end
  end

  defp find_ifname_index([], _ifname), do: nil
  defp find_ifname_index([{ifname, index} | _rest], ifname), do: index
  defp find_ifname_index([_no | rest], ifname), do: find_ifname_index(rest, ifname)

  defp domain_text({domain, ifnames}),
    do: ["search ", domain, " # From ", Enum.join(ifnames, ","), "\n"]

  defp name_server_text(%{address: address, from: ifnames}) do
    ["nameserver ", IP.ip_to_string(address), " # From ", Enum.join(ifnames, ","), "\n"]
  end
end
