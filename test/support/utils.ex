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
    {:ok, addrs} = :inet.getifaddrs()
    [{ifname, _info} | _rest] = Enum.filter(addrs, &good_interface?/1)
    to_string(ifname)
  end

  defp good_interface?({[?l, ?o | _anything], _}), do: false

  defp good_interface?({_ifname, fields}) do
    Enum.member?(fields[:flags], :up) and Enum.any?(fields, &ipv4_address_field?/1)
  end

  defp ipv4_address_field?({:addr, {_, _, _, _}}), do: true
  defp ipv4_address_field?(_), do: false

  @spec get_loopback_ifname() :: VintageNet.ifname()
  def get_loopback_ifname() do
    {:ok, addrs} = :inet.getifaddrs()
    [{ifname, _info} | _rest] = Enum.filter(addrs, &loopback_interface?/1)
    to_string(ifname)
  end

  defp loopback_interface?({[?l, ?o | _anything], fields}) do
    Enum.member?(fields[:flags], :up) and Enum.any?(fields, &ipv4_address_field?/1)
  end

  defp loopback_interface?({_ifname, _fields}), do: false
end
