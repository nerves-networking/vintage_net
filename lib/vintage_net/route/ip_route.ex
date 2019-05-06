defmodule VintageNet.Route.IPRoute do
  @moduledoc """
  This module knows how to invoke `ip` to change the routing table
  """

  require Logger

  @spec do_add_default_route(String.t(), :inet.ip_address(), non_neg_integer()) ::
          :ok | {:error, any()}
  def do_add_default_route(ifname, route, metric) do
    _ = Logger.info("ip route add default metric #{metric} via #{inspect(route)} dev #{ifname}")

    ip_cmd([
      "route",
      "add",
      "default",
      "metric",
      "#{metric}",
      "via",
      ip_to_string(route),
      "dev",
      ifname
    ])
  end

  @spec do_add_table(:inet.ip_address(), non_neg_integer()) :: :ok | {:error, any()}
  def do_add_table(ip_address, table) do
    _ = Logger.info("ip rule add from #{inspect(ip_address)} lookup #{table}")

    ip_cmd(["rule", "add", "from", ip_to_string(ip_address), "lookup", to_string(table)])
  end

  @spec do_clear_table(non_neg_integer()) :: :ok | {:error, any()}
  def do_clear_table(table) do
    _ = Logger.info("ip rule del lookup #{table}")

    ip_cmd(["rule", "del", "lookup", to_string(table)])
  end

  @spec do_clear_routes(String.t()) :: :ok | {:error, any()}
  def do_clear_routes(ifname) do
    _ = Logger.info("ip route del default dev #{ifname}")
    ip_cmd(["route", "del", "default", "dev", ifname])
  end

  @spec do_clear_all_routes() :: :ok | {:error, any()}
  def do_clear_all_routes() do
    _ = Logger.info("ip route del default")

    ip_cmd(["route", "del", "default"])
  end

  defp ip_cmd(args) do
    bin_ip = Application.get_env(:vintage_net, :bin_ip)

    case System.cmd(bin_ip, args) do
      {_, 0} -> :ok
      {message, _error} -> {:error, message}
    end
  end

  defp ip_to_string(ipa) do
    :inet.ntoa(ipa) |> to_string()
  end
end
