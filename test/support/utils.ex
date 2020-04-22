defmodule VintageNetTest.Utils do
  @moduledoc false

  @spec default_opts() :: keyword()
  def default_opts() do
    # Use the defaults in mix.exs, but normalize the paths to commands
    Application.get_all_env(:vintage_net)
    |> Keyword.merge(
      bin_chat: "chat",
      bin_dnsd: "dnsd",
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

  @spec udhcpc_child_spec(VintageNet.ifname(), String.t()) :: Supervisor.child_spec()
  def udhcpc_child_spec(ifname, hostname) do
    %{
      id: :udhcpc,
      restart: :permanent,
      shutdown: 500,
      start:
        {MuonTrap.Daemon, :start_link,
         [
           "udhcpc",
           [
             "-f",
             "-i",
             ifname,
             "-x",
             "hostname:#{hostname}",
             "-s",
             Application.app_dir(:vintage_net, ["priv", "udhcpc_handler"])
           ],
           [stderr_to_stdout: true, log_output: :debug, log_prefix: "udhcpc(#{ifname}): "]
         ]},
      type: :worker
    }
  end

  @spec udhcpd_child_spec(VintageNet.ifname()) :: Supervisor.child_spec()
  def udhcpd_child_spec(ifname) do
    %{
      id: :udhcpd,
      restart: :permanent,
      shutdown: 500,
      start:
        {MuonTrap.Daemon, :start_link,
         [
           "udhcpd",
           [
             "-f",
             "/tmp/vintage_net/udhcpd.conf.#{ifname}"
           ],
           [stderr_to_stdout: true, log_output: :debug]
         ]},
      type: :worker
    }
  end
end
