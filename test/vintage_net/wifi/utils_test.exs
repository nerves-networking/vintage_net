defmodule VintageNet.WiFi.UtilsTest do
  use ExUnit.Case

  alias VintageNet.WiFi.Utils

  test "2.4 Ghz channels" do
    for channel <- 1..13 do
      info = Utils.frequency_info(2407 + channel * 5)
      assert info.channel == channel
      assert info.band == :wifi_2_4_ghz
      assert info.band_name == "2.4 GHz"
    end

    assert %{channel: 14, band: :wifi_2_4_ghz, band_name: "2.4 GHz"} == Utils.frequency_info(2484)
  end

  test "5 Ghz channels" do
    count_high =
      for channel <- 7..173 do
        case Utils.frequency_info(5035 + (channel - 7) * 5) do
          %{channel: ^channel, band: :wifi_5_ghz, band_name: "5 GHz"} ->
            1

          %{channel: 0, band: :unknown} ->
            0
        end
      end

    count_low =
      for channel <- 183..196 do
        case Utils.frequency_info(4915 + (channel - 183) * 5) do
          %{channel: ^channel, band: :wifi_5_ghz, band_name: "5 GHz"} ->
            1

          %{channel: 0, band: :unknown} ->
            0
        end
      end

    # There are 65 possible 5 GHz channels
    total = Enum.sum(count_low) + Enum.sum(count_high)
    assert total == 65
  end

  test "power increases monotonically and is in range" do
    percents = for dbm <- -130..0, do: Utils.dbm_to_percent(dbm)

    assert 100 == Enum.max(percents)
    assert 1 == Enum.min(percents)

    assert Enum.sort(percents) == percents
  end

  test "power percent spot checks" do
    assert 93 == Utils.dbm_to_percent(-34)
    assert 85 == Utils.dbm_to_percent(-44)
    assert 74 == Utils.dbm_to_percent(-54)
    assert 60 == Utils.dbm_to_percent(-64)
    assert 42 == Utils.dbm_to_percent(-74)
    assert 22 == Utils.dbm_to_percent(-84)
    assert 1 == Utils.dbm_to_percent(-94)
  end
end
