defmodule VintageNetTest.Utils do
  def default_opts() do
    # Use the defaults in mix.exs
    Application.get_all_env(:vintage_net)
  end

  def dhcp_interface(ifname, hostname) do
    """
    iface #{ifname} inet dhcp
      script #{Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])}
      hostname #{hostname}
    """
  end
end
