defmodule VintageNet.ConfigLTETest do
  use ExUnit.Case
  alias VintageNet.Config

  defp default_opts() do
    [
      network_interfaces: "/tmp/network_interfaces",
      tmpdir: "/tmp",
      wpa_supplicant_conf: "/tmp/wpa_supplicant.conf",
      wpa_supplicant_control: "/tmp/foo",
      ifup: "/sbin/ifup",
      ifdown: "/sbin/ifdown",
      chat_bin: "/usr/sbin/chat",
      pppd: "/usr/sbin/pppd",
      mknod: "/bin/mknod",
      killall: "/usr/bin/killall",
      wpa_supplicant: "/usr/sbin/wpa_supplicant"
    ]
  end

  test "create an LTE configuration" do
    input = [
      {"ppp0",
       %{
         type: :mobile,
         pppd: %{
           options: [:noipdefault, :usepeerdns, :defaultroute, :persist, :noauth],
           chat_script: """
           ABORT 'BUSY'
           ABORT 'NO CARRIER'
           ABORT 'NO DIALTONE'
           ABORT 'NO DIAL TONE'
           ABORT 'NO ANSWER'
           ABORT 'DELAYED'
           TIMEOUT 12
           REPORT CONNECT
           "" AT
           OK ATH
           OK ATZ
           OK ATQ0
           OK AT+CGDCONT=1,"IP","hologram"
           OK ATDT*99***1#
           CONNECT ''
           """,
           ttyname: "/dev/ttyUSB1",
           speed: 115_200
         }
       }}
    ]

    output = %{
      files: [],
      up_cmds: [
        "/bin/mknod /dev/ppp c 108 0",
        "/usr/sbin/pppd connect \"/usr/sbin/chat -v -f /tmp/chat_script\" /dev/ttyUSB1 115200 noipdefault usepeerdns defaultroute noauth persist noauth"
      ],
      down_cmds: ["/usr/bin/killall -q pppd"]
    }

    assert output == Config.make(input, default_opts())
  end
end
