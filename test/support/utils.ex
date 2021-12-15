defmodule VintageNetTest.Utils do
  @moduledoc false

  @spec default_opts() :: keyword()
  def default_opts() do
    Application.get_all_env(:vintage_net)
  end

  @spec udhcpc_child_spec(VintageNet.ifname(), String.t()) :: Supervisor.child_spec()
  def udhcpc_child_spec(ifname, hostname) do
    %{
      id: :udhcpc,
      start:
        {VintageNet.Interface.IfupDaemon, :start_link,
         [
           [
             ifname: ifname,
             command: "udhcpc",
             args: [
               "-f",
               "-i",
               ifname,
               "-x",
               "hostname:#{hostname}",
               "-s",
               BEAMNotify.bin_path()
             ],
             opts: [
               stderr_to_stdout: true,
               log_output: :debug,
               log_prefix: "udhcpc(#{ifname}): ",
               env: BEAMNotify.env(name: "vintage_net_comm", report_env: true)
             ]
           ]
         ]}
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

  @spec get_ifname_for_tests() :: VintageNet.ifname()
  def get_ifname_for_tests() do
    case :inet.getifaddrs() do
      {:ok, addrs} ->
        addrs
        |> Enum.filter(&filter_interfaces/1)
        |> List.first()
        |> elem(0)
        |> to_string()
    end
  end

  defp filter_interfaces({[?l, ?o | _anything], _}), do: false

  defp filter_interfaces({_ifname, fields}) do
    Enum.member?(fields[:flags], :up) and fields[:addr] != nil
  end
end
