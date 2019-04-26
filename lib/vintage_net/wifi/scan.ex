defmodule VintageNet.WiFi.Scan do
  @doc """
  Scan wireless interface for other access points
  """
  @spec scan(String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def scan(ifname \\ "wlan0") do
    # might want to be smarter here about bringing up `wpa_supplicant` for an interface
    # to be able to use wpa_cli, however this is dumb for now, and if wpa_supplicant is
    # not running this will just return {:error, ""}
    ctrl_interface = "/tmp/wpa_supplicant/" <> ifname

    with {_, 0} <- System.cmd("wpa_cli", ["-i", ifname, "-g", ctrl_interface, "scan"]),
         _ <- :timer.sleep(5_000),
         {results, 0} <-
           System.cmd("wpa_cli", ["-i", ifname, "-g", ctrl_interface, "scan_results"]) do
      ssids =
        results
        |> String.split("\n", trim: true)
        |> Enum.drop(1)
        |> Enum.map(&(&1 |> String.split("\t") |> List.last()))

      {:ok, ssids}
    else
      {error, 255} -> {:error, error}
    end
  end
end
