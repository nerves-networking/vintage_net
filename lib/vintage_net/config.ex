defmodule VintageNet.Config do
  alias VintageNet.Interface.RawConfig
  alias VintageNet.WiFi

  @doc """
  Builds a vintage network configuration
  """
  @spec make([String.t()], keyword()) :: [RawConfig.t()]
  def make(networks, opts \\ []) do
    merged_opts = Application.get_all_env(:vintage_net) |> Keyword.merge(opts)
    Enum.map(networks, &do_make(&1, merged_opts))
  end

  defp do_make({ifname, %{type: :mobile, pppd: pppd_config}}, opts) do
    mknod = Keyword.fetch!(opts, :bin_mknod)
    killall = Keyword.fetch!(opts, :bin_killall)
    chat_bin = Keyword.fetch!(opts, :bin_chat)
    pppd = Keyword.fetch!(opts, :bin_pppd)

    files = [{"/tmp/chat_script", pppd_config.chat_script}]

    up_cmds = [
      {:run, mknod, ["/dev/ppp", "c", "108", "0"]},
      {:run, pppd, make_pppd_args(pppd_config, chat_bin)}
    ]

    down_cmds = [
      {:run, killall, ["-q", "pppd"]}
    ]

    %RawConfig{ifname: ifname, files: files, up_cmds: up_cmds, down_cmds: down_cmds}
  end

  defp do_make({_ifname, %{type: :wifi}} = config, opts) do
    WiFi.create(config, opts)
  end

  defp do_make({ifname, %{type: :ethernet} = _config}, opts) do
    ifup = Keyword.fetch!(opts, :bin_ifup)
    ifdown = Keyword.fetch!(opts, :bin_ifdown)

    %RawConfig{
      ifname: ifname,
      files: [
        {"/tmp/network_interfaces.#{ifname}", "iface #{ifname} inet dhcp" <> dhcp_options()}
      ],
      # ifup hangs forever until Ethernet is plugged in
      up_cmd_millis: 60_000,
      up_cmds: [{:run, ifup, ["-i", "/tmp/network_interfaces.#{ifname}", ifname]}],
      down_cmd_millis: 5_000,
      down_cmds: [{:run, ifdown, ["-i", "/tmp/network_interfaces.#{ifname}", ifname]}]
    }
  end

  defp make_pppd_args(pppd, chat_bin) do
    [
      "connect",
      "#{chat_bin} -v -f /tmp/chat_script",
      pppd.ttyname,
      "#{pppd.speed}"
    ] ++ Enum.map(pppd.options, &pppd_option_to_string/1)
  end

  defp pppd_option_to_string(:noipdefault), do: "noipdefault"
  defp pppd_option_to_string(:usepeerdns), do: "usepeerdns"
  defp pppd_option_to_string(:defaultroute), do: "defaultroute"
  defp pppd_option_to_string(:persist), do: "persist"
  defp pppd_option_to_string(:noauth), do: "noauth"

  defp dhcp_options() do
    """

      script #{udhcpc_handler_path()}
    """
  end

  defp udhcpc_handler_path() do
    Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])
  end
end
