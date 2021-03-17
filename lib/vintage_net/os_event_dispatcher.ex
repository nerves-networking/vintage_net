defmodule VintageNet.OSEventDispatcher do
  @moduledoc false
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
  def dispatch(["udhcpd." <> ifname_leases = lease_file], _env) do
    [ifname, "leases"] = String.split(ifname_leases, ".", parts: 2)
    handler = Application.get_env(:vintage_net, :udhcpd_handler)
    apply(handler, :lease_update, [ifname, lease_file])
  end

  def dispatch([op], %{"interface" => ifname} = info)
      when op in ["deconfig", "leasefail", "nak", "renew", "bound"] do
    handler = Application.get_env(:vintage_net, :udhcpc_handler)

    new_info = info |> key_to_list("dns") |> key_to_list("router")

    apply(handler, String.to_atom(op), [ifname, new_info])
  end

  def dispatch(args, _env) do
    Logger.warn("VintageNet: dropping unexpected notification: #{inspect(args)}")
  end

  # This preserves the behavior of an earlier version of this code.
  defp key_to_list(info, key) do
    case Map.fetch(info, key) do
      {:ok, s} -> %{info | key => String.split(s, " ", trim: true)}
      :error -> info
    end
  end
end
