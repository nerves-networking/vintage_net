defmodule VintageNet.OSEventDispatcher do
  @moduledoc false
  alias VintageNet.DHCP.Options
  require Logger

  @doc """
  Called by BEAMNotify to report OS events

  Currently this includes reports from:

  * `udhcpc`
  * `udhcpd`

  The first parameter is a list of arguments and the second is the
  OS environment.
  """
  @spec dispatch([String.t()], %{String.t() => String.t()}) :: :ok
  def dispatch([op], %{"interface" => ifname} = info)
      when op in ["deconfig", "leasefail", "nak", "renew", "bound"] do
    # udhcpc update
    handler = Application.get_env(:vintage_net, :udhcpc_handler)
    dhcp_options = Options.udhcpc_to_options(info)

    if op in ["deconfig", "leasefail", "nak"] do
      PropertyTable.delete(VintageNet, ["interface", ifname, "dhcp_options"])
    else
      PropertyTable.put(VintageNet, ["interface", ifname, "dhcp_options"], dhcp_options)
    end

    apply(handler, String.to_atom(op), [ifname, dhcp_options])
  end

  def dispatch([lease_file], _env) do
    # udhcpd update
    case extract_lease_file_ifname(lease_file) do
      {:ok, ifname} ->
        handler = Application.get_env(:vintage_net, :udhcpd_handler)
        handler.lease_update(ifname, lease_file)

      :error ->
        Logger.warning("VintageNet: dropping unexpected notification: [#{inspect(lease_file)}]")
    end
  end

  def dispatch(args, _env) do
    Logger.warning("VintageNet: dropping unexpected notification: #{inspect(args)}")
  end

  defp extract_lease_file_ifname(path) do
    # "/tmp/vintage_net/udhcpd.wlan0.leases"
    base = Path.basename(path)

    case String.split(base, ".", parts: 3) do
      ["udhcpd", ifname, "leases"] -> {:ok, ifname}
      _ -> :error
    end
  end
end
