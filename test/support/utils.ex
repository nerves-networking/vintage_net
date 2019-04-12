defmodule VintageNetTest.Utils do
  def default_opts() do
    # Use the defaults in mix.exs
    []
  end

  def dhcp_interface(ifname) do
    """
    iface #{ifname} inet dhcp
      script #{Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])}
    """
  end
end
