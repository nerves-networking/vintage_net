defmodule VintageNet.WiFi.Utils do
  @moduledoc """
  Various utility functions for handling WiFi information
  """

  @type band() :: :wifi_2_4_ghz | :wifi_5_ghz | :unknown
  @type info() :: %{
          band: band(),
          band_name: String.t(),
          channel: non_neg_integer()
        }

  @doc """
  Convert power in dBm to a percent

  The returned percentage is intended to shown to users
  like to show a number of bars or some kind of signal
  strength.

  See https://web.archive.org/web/20141222024740/http://www.ces.clemson.edu/linux/nm-ipw2200.shtml
  """
  @spec dbm_to_percent(number(), number(), number()) :: 1..100
  def dbm_to_percent(dbm, best_dbm \\ -20, worst_dbm \\ -83.7)

  def dbm_to_percent(dbm, best_dbm, _worst_dbm) when dbm >= best_dbm do
    100
  end

  def dbm_to_percent(dbm, best_dbm, worst_dbm) do
    delta = best_dbm - worst_dbm
    delta2 = delta * delta

    percent =
      100 -
        (best_dbm - dbm) * (15 * delta + 62 * (best_dbm - dbm)) /
          delta2

    # Constrain the percent to integers and never go to 0
    max(floor(percent), 1)
  end

  @doc """
  Get information about a WiFi frequency

  The frequency should be pass in MHz. The result is more
  information about the frequency that may be helpful to
  users.
  """
  @spec frequency_info(non_neg_integer()) :: info()
  def(frequency_info(2412), do: band2_4(1))
  def frequency_info(2417), do: band2_4(2)
  def frequency_info(2422), do: band2_4(3)
  def frequency_info(2427), do: band2_4(4)
  def frequency_info(2432), do: band2_4(5)
  def frequency_info(2437), do: band2_4(6)
  def frequency_info(2442), do: band2_4(7)
  def frequency_info(2447), do: band2_4(8)
  def frequency_info(2452), do: band2_4(9)
  def frequency_info(2457), do: band2_4(10)
  def frequency_info(2462), do: band2_4(11)
  def frequency_info(2467), do: band2_4(12)
  def frequency_info(2472), do: band2_4(13)
  def frequency_info(2484), do: band2_4(14)

  def frequency_info(5035), do: band5(7)
  def frequency_info(5040), do: band5(8)
  def frequency_info(5045), do: band5(9)
  def frequency_info(5055), do: band5(11)
  def frequency_info(5060), do: band5(12)
  def frequency_info(5080), do: band5(16)
  def frequency_info(5160), do: band5(32)
  def frequency_info(5170), do: band5(34)
  def frequency_info(5180), do: band5(36)
  def frequency_info(5190), do: band5(38)
  def frequency_info(5200), do: band5(40)
  def frequency_info(5210), do: band5(42)
  def frequency_info(5220), do: band5(44)
  def frequency_info(5230), do: band5(46)
  def frequency_info(5240), do: band5(48)
  def frequency_info(5250), do: band5(50)
  def frequency_info(5260), do: band5(52)
  def frequency_info(5270), do: band5(54)
  def frequency_info(5280), do: band5(56)
  def frequency_info(5290), do: band5(58)
  def frequency_info(5300), do: band5(60)
  def frequency_info(5310), do: band5(62)
  def frequency_info(5320), do: band5(64)
  def frequency_info(5340), do: band5(68)
  def frequency_info(5480), do: band5(96)
  def frequency_info(5500), do: band5(100)
  def frequency_info(5510), do: band5(102)
  def frequency_info(5520), do: band5(104)
  def frequency_info(5530), do: band5(106)
  def frequency_info(5540), do: band5(108)
  def frequency_info(5550), do: band5(110)
  def frequency_info(5560), do: band5(112)
  def frequency_info(5570), do: band5(114)
  def frequency_info(5580), do: band5(116)
  def frequency_info(5590), do: band5(118)
  def frequency_info(5600), do: band5(120)
  def frequency_info(5610), do: band5(122)
  def frequency_info(5620), do: band5(124)
  def frequency_info(5630), do: band5(126)
  def frequency_info(5640), do: band5(128)
  def frequency_info(5660), do: band5(132)
  def frequency_info(5670), do: band5(134)
  def frequency_info(5680), do: band5(136)
  def frequency_info(5690), do: band5(138)
  def frequency_info(5700), do: band5(140)
  def frequency_info(5710), do: band5(142)
  def frequency_info(5720), do: band5(144)
  def frequency_info(5745), do: band5(149)
  def frequency_info(5755), do: band5(151)
  def frequency_info(5765), do: band5(153)
  def frequency_info(5775), do: band5(155)
  def frequency_info(5785), do: band5(157)
  def frequency_info(5795), do: band5(159)
  def frequency_info(5805), do: band5(161)
  def frequency_info(5825), do: band5(165)
  def frequency_info(5845), do: band5(169)
  def frequency_info(5865), do: band5(173)
  def frequency_info(4915), do: band5(183)
  def frequency_info(4920), do: band5(184)
  def frequency_info(4925), do: band5(185)
  def frequency_info(4935), do: band5(187)
  def frequency_info(4940), do: band5(188)
  def frequency_info(4945), do: band5(189)
  def frequency_info(4960), do: band5(192)
  def frequency_info(4980), do: band5(196)

  def frequency_info(unknown) do
    %{band: :unknown, band_name: "#{unknown} Mhz", channel: 0}
  end

  defp band2_4(channel) do
    %{band: :wifi_2_4_ghz, band_name: "2.4 GHz", channel: channel}
  end

  defp band5(channel) do
    %{band: :wifi_5_ghz, band_name: "5 GHz", channel: channel}
  end
end
