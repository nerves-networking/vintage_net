defmodule VintageNet.WiFi.WPASupplicantDecoder do
  @doc """
  Decode notifications from the wpa_supplicant
  """
  def decode_notification(<<"CTRL-REQ-", rest::binary>>) do
    [field, net_id, text] = String.split(rest, "-", parts: 3, trim: true)
    {:interactive, "CTRL-REQ-" <> field, String.to_integer(net_id), text}
  end

  def decode_notification(<<"CTRL-EVENT-BSS-ADDED", rest::binary>>) do
    [entry_id, bssid] = String.split(rest, " ", trim: true)
    {:event, "CTRL-EVENT-BSS-ADDED", String.to_integer(entry_id), bssid}
  end

  def decode_notification(<<"CTRL-EVENT-BSS-REMOVED", rest::binary>>) do
    [entry_id, bssid] = String.split(rest, " ", trim: true)
    {:event, "CTRL-EVENT-BSS-REMOVED", String.to_integer(entry_id), bssid}
  end

  # This message is just not shaped the same as others for some reason.
  def decode_notification(<<"CTRL-EVENT-CONNECTED", rest::binary>>) do
    ["-", "Connection", "to", bssid, status | info] = String.split(rest)

    info =
      Regex.scan(~r(\w+=[a-zA-Z0-9:\"_]+), Enum.join(info, " "))
      |> Map.new(fn [str] ->
        [key, val] = String.split(str, "=")
        {key, kv_value(val)}
      end)

    {:event, "CTRL-EVENT-CONNECTED", bssid, status, info}
  end

  def decode_notification(<<"CTRL-EVENT-DISCONNECTED", rest::binary>>) do
    decode_kv_notification("CTRL-EVENT-DISCONNECTED", rest)
  end

  # "CTRL-EVENT-REGDOM-CHANGE init=CORE"
  def decode_notification(<<"CTRL-EVENT-REGDOM-CHANGE", rest::binary>>) do
    decode_kv_notification("CTRL-EVENT-REGDOM-CHANGE", rest)
  end

  # "CTRL-EVENT-ASSOC-REJECT bssid=00:00:00:00:00:00 status_code=16"
  def decode_notification(<<"CTRL-EVENT-ASSOC-REJECT", rest::binary>>) do
    decode_kv_notification("CTRL-EVENT-ASSOC-REJECT", rest)
  end

  # "CTRL-EVENT-SSID-TEMP-DISABLED id=1 ssid=\"FarmbotConnect\" auth_failures=1 duration=10 reason=CONN_FAILED"
  def decode_notification(<<"CTRL-EVENT-SSID-TEMP-DISABLED", rest::binary>>) do
    decode_kv_notification("CTRL-EVENT-SSID-TEMP-DISABLED", rest)
  end

  # "CTRL-EVENT-SUBNET-STATUS-UPDATE status=0"
  def decode_notification(<<"CTRL-EVENT-SUBNET-STATUS-UPDATE", rest::binary>>) do
    decode_kv_notification("CTRL-EVENT-SUBNET-STATUS-UPDATE", rest)
  end

  # CTRL-EVENT-SSID-REENABLED id=1 ssid=\"FarmbotConnect\""
  def decode_notification(<<"CTRL-EVENT-SSID-REENABLED", rest::binary>>) do
    decode_kv_notification("CTRL-EVENT-SSID-REENABLED", rest)
  end

  def decode_notification(<<"CTRL-EVENT-EAP-PEER-CERT", rest::binary>>) do
    info =
      rest
      |> String.trim()
      |> String.split(" ")
      |> Map.new(fn str ->
        [key, val] = String.split(str, "=", parts: 2)
        {key, kv_value(val)}
      end)

    {:event, "CTRL-EVENT-EAP-PEER-CERT", info}
  end

  def decode_notification(<<"CTRL-EVENT-EAP-STATUS", rest::binary>>) do
    info =
      Regex.scan(~r/\w+=(["'])(?:(?=(\\?))\2.)*?\1/, rest)
      |> Map.new(fn [str | _] ->
        [key, val] = String.split(str, "=", parts: 2)
        {key, kv_value(val)}
      end)

    {:event, "CTRL-EVENT-EAP-STATUS", info}
  end

  def decode_notification(<<"CTRL-EVENT-EAP-FAILURE", rest::binary>>) do
    {:event, "CTRL-EVENT-EAP-FAILURE", String.trim(rest)}
  end

  def decode_notification(<<"CTRL-EVENT-EAP-METHOD", rest::binary>>) do
    {:event, "CTRL-EVENT-EAP-METHOD", String.trim(rest)}
  end

  def decode_notification(<<"CTRL-EVENT-EAP-PROPOSED-METHOD", rest::binary>>) do
    decode_kv_notification("CTRL-EVENT-EAP-PROPOSED-METHOD", rest)
  end

  def decode_notification(<<"CTRL-EVENT-", _type::binary>> = event) do
    {:event, String.trim_trailing(event)}
  end

  def decode_notification(<<"WPS-", _type::binary>> = event) do
    {:event, String.trim_trailing(event)}
  end

  def decode_notification(<<"AP-STA-CONNECTED ", mac::binary>>) do
    {:event, "AP-STA-CONNECTED", String.trim_trailing(mac)}
  end

  def decode_notification(<<"AP-STA-DISCONNECTED ", mac::binary>>) do
    {:event, "AP-STA-DISCONNECTED", String.trim_trailing(mac)}
  end

  def decode_notification(string) do
    {:info, String.trim_trailing(string)}
  end

  defp decode_kv_notification(event, rest) do
    info =
      Regex.scan(~r(\w+=[\S*]+), rest)
      |> Map.new(fn [str] ->
        str = String.replace(str, "\'", "")
        [key, val] = String.split(str, "=", parts: 2)
        {key, kv_value(val)}
      end)

    case Map.pop(info, "bssid") do
      {nil, _original} -> {:event, event, info}
      {bssid, new_info} -> {:event, event, bssid, new_info}
    end
  end

  @doc """
  Decode a key-value response from the wpa_supplicant
  """
  @spec decode_kv_response(String.t()) :: map()
  def decode_kv_response(resp) do
    resp
    |> String.split("\n", trim: true)
    |> List.foldl(%{}, fn pair, acc ->
      case String.split(pair, "=") do
        [key, value] ->
          acc
          |> Map.put(key, kv_value(String.trim_trailing(value)))

        _ ->
          # Skip
          acc
      end
    end)
  end

  defp kv_value("TRUE"), do: true
  defp kv_value("FALSE"), do: false
  defp kv_value(""), do: nil
  defp kv_value(<<"\"", _::binary>> = msg), do: String.trim(msg, "\"")
  defp kv_value(<<"\'", _::binary>> = msg), do: String.trim(msg, "\'")
  defp kv_value(<<"0x", hex::binary>>), do: kv_value(hex, 16)
  defp kv_value(str), do: kv_value(str, 10)

  defp kv_value(value, base) do
    try do
      String.to_integer(value, base)
    rescue
      ArgumentError -> value
    end
  end
end
