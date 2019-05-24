defmodule VintageNet.Route.IPRoute do
  @moduledoc """
  This module knows how to invoke `ip` to change the routing table
  """

  require Logger

  alias VintageNet.Route.Calculator

  @doc """
  Add a default route
  """
  @spec add_default_route(
          VintageNet.ifname(),
          :inet.ip_address(),
          Calculator.metric(),
          Calculator.table_index()
        ) ::
          :ok | {:error, any()}
  def add_default_route(ifname, route, metric, table_index) do
    table_index_string = table_index_to_string(table_index)

    ip_cmd([
      "route",
      "add",
      "default",
      "table",
      table_index_string,
      "metric",
      "#{metric}",
      "via",
      ip_to_string(route),
      "dev",
      ifname
    ])
  end

  @doc """
  Add a local route
  """
  @spec add_local_route(
          VintageNet.ifname(),
          :inet.ip_address(),
          Calculator.subnet_bits(),
          Calculator.metric(),
          Calculator.table_index()
        ) ::
          :ok | {:error, any()}
  def add_local_route(ifname, ip, subnet_bits, metric, table_index) do
    subnet = Calculator.to_subnet(ip, subnet_bits)
    subnet_string = ip_to_string(subnet) <> "/" <> to_string(subnet_bits)
    table_index_string = table_index_to_string(table_index)

    ip_cmd([
      "route",
      "add",
      subnet_string,
      "table",
      table_index_string,
      "metric",
      to_string(metric),
      "dev",
      ifname,
      "scope",
      "link",
      "src",
      ip_to_string(ip)
    ])
  end

  @doc """
  Add a source IP address -> routing table rule
  """
  @spec add_rule(:inet.ip_address(), Calculator.table_index()) :: :ok | {:error, any()}
  def add_rule(ip_address, table_index) do
    table_index_string = table_index_to_string(table_index)

    ip_cmd(["rule", "add", "from", ip_to_string(ip_address), "lookup", table_index_string])
  end

  @doc """
  Clear all routes on all interfaces
  """
  @spec clear_all_routes() :: :ok
  def clear_all_routes() do
    repeat_til_error(&clear_a_route/0)
  end

  @doc """
  Clear all rules that select the specified table or tables
  """
  @spec clear_all_rules(Calculator.table_index() | Enumerable.t()) :: :ok
  def clear_all_rules(table_index) when is_integer(table_index) or is_atom(table_index) do
    repeat_til_error(fn -> clear_a_rule(table_index) end)
  end

  def clear_all_rules(table_indices) do
    Enum.each(table_indices, &clear_all_rules/1)
  end

  defp repeat_til_error(function) do
    case function.() do
      :ok ->
        # Success. There could be more, though.
        repeat_til_error(function)

      _ ->
        # Error, so stop
        :ok
    end
  end

  @spec clear_a_route() :: :ok | {:error, any()}
  def clear_a_route() do
    ip_cmd(["route", "del", "default"])
  end

  @spec clear_a_route(VintageNet.ifname(), Calculator.table_index()) :: :ok | {:error, any()}
  def clear_a_route(ifname, table_index \\ :main) do
    table_index_string = table_index_to_string(table_index)
    ip_cmd(["route", "del", "default", "table", table_index_string, "dev", ifname])
  end

  @spec clear_a_local_route(
          VintageNet.ifname(),
          :inet.ip_address(),
          Calculator.subnet_bits(),
          Calculator.metric(),
          Calculator.table_index()
        ) ::
          :ok | {:error, any()}
  def clear_a_local_route(ifname, ip, subnet_bits, metric, table_index) do
    subnet = Calculator.to_subnet(ip, subnet_bits)
    subnet_string = ip_to_string(subnet) <> "/" <> to_string(subnet_bits)
    table_index_string = table_index_to_string(table_index)

    ip_cmd([
      "route",
      "del",
      subnet_string,
      "table",
      table_index_string,
      "metric",
      "#{metric}",
      "dev",
      ifname,
      "scope",
      "link"
    ])
  end

  @spec clear_a_local_route(VintageNet.ifname()) :: :ok | {:error, any()}
  def clear_a_local_route(ifname) do
    ip_cmd(["route", "del", "dev", ifname, "scope", "link"])
  end

  @spec clear_a_rule(Calculator.table_index()) :: :ok | {:error, any()}
  def clear_a_rule(table_index) do
    table_index_string = table_index_to_string(table_index)

    ip_cmd(["rule", "del", "lookup", table_index_string])
  end

  defp table_index_to_string(:main), do: "main"

  defp table_index_to_string(table_index) when table_index >= 0 and table_index <= 255,
    do: to_string(table_index)

  defp ip_cmd(args) do
    bin_ip = Application.get_env(:vintage_net, :bin_ip)

    # Send iodata to the logger with the command and args interspersed with spaces
    # _ = Logger.debug(Enum.intersperse(["ip" | args], " "))

    case System.cmd(bin_ip, args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {message, _error} -> {:error, message}
    end
  end

  defp ip_to_string(ipa) do
    :inet.ntoa(ipa) |> to_string()
  end
end
