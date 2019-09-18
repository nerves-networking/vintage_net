defmodule VintageNet.Technology.MobileTest do
  use ExUnit.Case
  alias VintageNet.Technology.Mobile
  alias VintageNet.Interface.RawConfig

  import VintageNetTest.Utils

  defp ppp_config() do
    %{
      type: VintageNet.Technology.Mobile,
      pppd: %{
        options: [:noipdefault, :usepeerdns, :defaultroute, :noauth, :persist],
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
    }
  end

  defp ppp_output(input) do
    %RawConfig{
      ifname: "ppp0",
      type: VintageNet.Technology.Mobile,
      source_config: input,
      files: [
        {"/tmp/chat_script",
         """
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
         """}
      ],
      up_cmds: [
        {:run, "mknod", ["/dev/ppp", "c", "108", "0"]},
        {:run, "pppd",
         [
           "connect",
           "chat -v -f /tmp/chat_script",
           "/dev/ttyUSB1",
           "115200",
           "noipdefault",
           "usepeerdns",
           "defaultroute",
           "noauth",
           "persist"
         ]}
      ],
      down_cmds: [{:run, "killall", ["-q", "pppd"]}]
    }
  end

  test "create an LTE configuration" do
    input = ppp_config()

    output = ppp_output(input)

    assert output == Mobile.to_raw_config("ppp0", input, default_opts())
  end
end
