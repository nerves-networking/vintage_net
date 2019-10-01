defmodule VintageNet.WiFi.WPA2Test do
  use ExUnit.Case
  alias VintageNet.WiFi.WPA2

  doctest WPA2

  test "returns error on bad passwords" do
    assert WPA2.to_psk(
             "SSID",
             "12345678901234567890123456789012345678901234567890123456789012345"
           ) == {:error, :password_too_long}

    assert WPA2.to_psk("SSID", <<1, 2, 3, 4, 5, 6, 7, 8>>) == {:error, :invalid_characters}

    assert WPA2.to_psk("SSID", "0123456") === {:error, :password_too_short}
  end

  test "returns error on bad SSIDs" do
    assert WPA2.to_psk("12345678901234567890123456789012345", "password")
  end

  test "passes IEEE 802.11i test vectors" do
    # See IEEE Std 802.11i-2004 Appendix H.4
    assert WPA2.to_psk("IEEE", "password") ==
             {:ok,
              "F42C6FC52DF0EBEF9EBB4B90B38A5F90" <>
                "2E83FE1B135A70E23AED762E9710A12E"}

    assert WPA2.to_psk("ThisIsASSID", "ThisIsAPassword") ==
             {:ok,
              "0DC0D6EB90555ED6419756B9A15EC3E3" <>
                "209B63DF707DD508D14581F8982721AF"}

    assert WPA2.to_psk("ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") ==
             {:ok,
              "BECB93866BB8C3832CB777C2F559807C" <>
                "8C59AFCB6EAE734885001300A981CC62"}
  end

  test "PSKs get passed through" do
    psk = "BECB93866BB8C3832CB777C2F559807C8C59AFCB6EAE734885001300A981CC62"

    assert WPA2.to_psk("anyssid", psk) == {:ok, psk}
  end
end
