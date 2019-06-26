defmodule VintageNetTest.Utils do
  def default_opts() do
    # Use the defaults in mix.exs, but normalize the paths to commands
    Application.get_all_env(:vintage_net)
    |> Keyword.merge(
      bin_ifup: "ifup",
      bin_ifdown: "ifdown",
      bin_chat: "chat",
      bin_pppd: "pppd",
      bin_mknod: "mknod",
      bin_killall: "killall",
      bin_wpa_supplicant: "wpa_supplicant",
      bin_ip: "ip",
      bin_udhcpd: "udhcpd",
      bin_dnsd: "dnsd"
    )
  end

  def dhcp_interface(ifname, hostname) do
    """
    iface #{ifname} inet dhcp
      script #{Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])}
      hostname #{hostname}
    """
  end
end
