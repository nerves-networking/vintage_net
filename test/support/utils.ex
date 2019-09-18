defmodule VintageNetTest.Utils do
  @spec default_opts() :: keyword()
  def default_opts() do
    # Use the defaults in mix.exs, but normalize the paths to commands
    Application.get_all_env(:vintage_net)
    |> Keyword.merge(
      bin_chat: "chat",
      bin_ifdown: "ifdown",
      bin_ifup: "ifup",
      bin_ip: "ip",
      bin_killall: "killall",
      bin_mknod: "mknod",
      bin_pppd: "pppd",
      bin_udhcpc: "udhcpc",
      bin_udhcpd: "udhcpd",
      bin_wpa_supplicant: "wpa_supplicant"
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
