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

  def dispatch([op], %{"interface" => ifname} = info)
      when op in ["deconfig", "leasefail", "nak", "renew", "bound"] do
    handler = Application.get_env(:vintage_net, :udhcpc_handler)

    new_info = info |> key_to_list("dns") |> key_to_list("router")

    apply(handler, String.to_atom(op), [ifname, new_info])
  end

  def dispatch([lease_file], _env) do
    case extract_lease_file_ifname(lease_file) do
      {:ok, ifname} ->
        handler = Application.get_env(:vintage_net, :udhcpd_handler)
        apply(handler, :lease_update, [ifname, lease_file])

      :error ->
        Logger.warn("VintageNet: dropping unexpected notification: [#{inspect(lease_file)}]")
    end
  end

  def dispatch(args, _env) do
    Logger.warn("VintageNet: dropping unexpected notification: #{inspect(args)}")
  end

  defp extract_lease_file_ifname(path) do
    # "/tmp/vintage_net/udhcpd.wlan0.leases"
    base = Path.basename(path)

    case String.split(base, ".", parts: 3) do
      ["udhcpd", ifname, "leases"] -> {:ok, ifname}
      _ -> :error
    end
  end

  # This preserves the behavior of an earlier version of this code.
  defp key_to_list(info, key) do
    case Map.fetch(info, key) do
      {:ok, s} -> %{info | key => String.split(s, " ", trim: true)}
      :error -> info
    end
  end
end
