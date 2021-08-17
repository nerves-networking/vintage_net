defmodule VintageNet.Interface.NameUtilities do
  @moduledoc """
  Module for classifying network interfaces
  """

  @doc """
  Classify a network type based on its name

  Examples

      iex> NameUtilities.to_type("eth0")
      :ethernet

      iex> NameUtilities.to_type("wlp5s0")
      :wifi

      iex> NameUtilities.to_type("wwan0")
      :mobile

  """
  @spec to_type(VintageNet.ifname()) :: VintageNet.interface_type()
  def to_type("eth" <> _rest), do: :ethernet
  def to_type("en" <> _rest), do: :ethernet
  def to_type("wlan" <> _rest), do: :wifi
  def to_type("wl" <> _rest), do: :wifi
  def to_type("ra" <> _rest), do: :wifi
  def to_type("ppp" <> _rest), do: :mobile
  def to_type("wwan" <> _rest), do: :mobile
  def to_type("lo" <> _rest), do: :local
  def to_type("tap" <> _rest), do: :local
  def to_type(_other), do: :unknown

  @doc """
  Extract a number out of an interface name

  The result is the interface index for most interfaces seen
  on Nerves (eth0, eth1, ...), and something quite imperfect when using predictable
  interface naming (enp6s0, enp6s1).

  This is currently used to order priorities when there are two
  interfaces available of the same type that cannot be differentiated
  by other means. It has the one property of being easy to explain.
  """
  @spec get_instance(VintageNet.ifname()) :: non_neg_integer()
  def get_instance(ifname) do
    ifname
    |> String.to_charlist()
    |> Enum.reduce(0, &add_numbers/2)
  end

  defp add_numbers(c, sum) when c >= ?0 and c <= ?9 do
    sum * 10 + c - ?0
  end

  defp add_numbers(_c, sum), do: sum
end
