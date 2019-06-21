defmodule VintageNet.WiFi.UtilsTest do
  use ExUnit.Case

  alias VintageNet.WiFi.Utils

  test "2.4 Ghz channels" do
    for channel <- 1..13 do
      info = Utils.frequency_info(2407 + channel * 5)
      assert info.channel == channel
      assert info.band == :wifi_2_4_ghz
    end

    info = Utils.frequency_info(2484)
    assert info.channel == 14
    assert info.band == :wifi_2_4_ghz
  end

  test "5 Ghz channels" do
    count_high =
      for channel <- 7..173 do
        case Utils.frequency_info(5035 + (channel - 7) * 5) do
          %{channel: ^channel, band: :wifi_5_ghz} ->
            1

          %{channel: 0, band: :unknown} ->
            0
        end
      end

    count_low =
      for channel <- 183..196 do
        case Utils.frequency_info(4915 + (channel - 183) * 5) do
          %{channel: ^channel, band: :wifi_5_ghz} ->
            1

          %{channel: 0, band: :unknown} ->
            0
        end
      end

    # There are 65 possible 5 GHz channels
    total = Enum.sum(count_low) + Enum.sum(count_high)
    assert total == 65
  end

  test "power increases monotonically and is in range for 2.4 GHz" do
    info = Utils.frequency_info(2484)
    percents = for dbm <- -130..0, do: info.dbm_to_percent.(dbm)

    assert 100 == Enum.max(percents)
    assert 1 == Enum.min(percents)

    assert Enum.sort(percents) == percents
  end

  test "power percent spot checks for 2.4 GHz" do
    info = Utils.frequency_info(2484)
    assert 93 == info.dbm_to_percent.(-34)
    assert 85 == info.dbm_to_percent.(-44)
    assert 74 == info.dbm_to_percent.(-54)
    assert 60 == info.dbm_to_percent.(-64)
    assert 42 == info.dbm_to_percent.(-74)
    assert 22 == info.dbm_to_percent.(-84)
    assert 1 == info.dbm_to_percent.(-94)
  end

  test "power increases monotonically and is in range for 5 GHz" do
    info = Utils.frequency_info(4915)
    percents = for dbm <- -130..0, do: info.dbm_to_percent.(dbm)

    assert 100 == Enum.max(percents)
    assert 1 == Enum.min(percents)

    assert Enum.sort(percents) == percents
  end
end
