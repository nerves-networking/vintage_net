defmodule VintageNet.IP do
  @moduledoc """
  This module contains utilities for handling IP addresses.

  By far the most important part of handling IP addresses is to
  pay attention to whether your addresses are names, IP addresses
  as strings or IP addresses at tuples. This module doesn't resolve
  names. While IP addresses in string form are convenient to type,
  nearly all Erlang and Elixir code uses IP addresses in tuple
  form.
  """

  defguardp is_ipv4_octet(v) when v >= 0 and v <= 255
  defguardp is_ipv6_hextet(v) when v >= 0 and v <= 65535

  @doc """
  Convert an IP address to a string

  Examples:

      iex> VintageNet.IP.ip_to_string({192, 168, 0, 1})
      "192.168.0.1"

      iex> VintageNet.IP.ip_to_string("192.168.9.1")
      "192.168.9.1"

      iex> VintageNet.IP.ip_to_string({65152, 0, 0, 0, 0, 0, 0, 1})
      "fe80::1"
  """
  @spec ip_to_string(VintageNet.any_ip_address()) :: String.t()
  def ip_to_string(ipa) when is_tuple(ipa) do
    :inet.ntoa(ipa) |> List.to_string()
  end

  def ip_to_string(ipa) when is_binary(ipa), do: ipa

  @doc """
  Convert an IP address w/ prefix to a CIDR-formatted string

  Examples:

      iex> VintageNet.IP.cidr_to_string({192, 168, 0, 1}, 24)
      "192.168.0.1/24"
  """
  @spec cidr_to_string(:inet.ip_address(), VintageNet.prefix_length()) :: String.t()
  def cidr_to_string(ipa, bits) do
    ip_to_string(ipa) <> "/" <> Integer.to_string(bits)
  end

  @doc """
  Convert an IP address to tuple form

  Examples:

      iex> VintageNet.IP.ip_to_tuple("192.168.0.1")
      {:ok, {192, 168, 0, 1}}

      iex> VintageNet.IP.ip_to_tuple({192, 168, 1, 1})
      {:ok, {192, 168, 1, 1}}

      iex> VintageNet.IP.ip_to_tuple("fe80::1")
      {:ok, {65152, 0, 0, 0, 0, 0, 0, 1}}

      iex> VintageNet.IP.ip_to_tuple({65152, 0, 0, 0, 0, 0, 0, 1})
      {:ok, {65152, 0, 0, 0, 0, 0, 0, 1}}

      iex> VintageNet.IP.ip_to_tuple("bologna")
      {:error, "Invalid IP address: bologna"}
  """
  @spec ip_to_tuple(VintageNet.any_ip_address()) ::
          {:ok, :inet.ip_address()} | {:error, String.t()}
  def ip_to_tuple({a, b, c, d} = ipa)
      when is_ipv4_octet(a) and is_ipv4_octet(b) and is_ipv4_octet(c) and is_ipv4_octet(d),
      do: {:ok, ipa}

  def ip_to_tuple({a, b, c, d, e, f, g, h} = ipa)
      when is_ipv6_hextet(a) and
             is_ipv6_hextet(b) and
             is_ipv6_hextet(c) and
             is_ipv6_hextet(d) and
             is_ipv6_hextet(e) and
             is_ipv6_hextet(f) and
             is_ipv6_hextet(g) and
             is_ipv6_hextet(h),
      do: {:ok, ipa}

  def ip_to_tuple(ipa) when is_binary(ipa) do
    case :inet.parse_address(to_charlist(ipa)) do
      {:ok, addr} -> {:ok, addr}
      {:error, :einval} -> {:error, "Invalid IP address: #{ipa}"}
    end
  end

  def ip_to_tuple(ipa), do: {:error, "Invalid IP address: #{inspect(ipa)}"}

  @doc """
  Raising version of ip_to_tuple/1
  """
  @spec ip_to_tuple!(VintageNet.any_ip_address()) :: :inet.ip_address()
  def ip_to_tuple!(ipa) do
    case ip_to_tuple(ipa) do
      {:ok, addr} ->
        addr

      {:error, error} ->
        raise ArgumentError, error
    end
  end

  @doc """
  Convert an IPv4 subnet mask to a prefix length.

  Examples:

      iex> VintageNet.IP.subnet_mask_to_prefix_length({255, 255, 255, 0})
      {:ok, 24}

      iex> VintageNet.IP.subnet_mask_to_prefix_length({192, 168, 1, 1})
      {:error, "{192, 168, 1, 1} is not a valid IPv4 subnet mask"}
  """
  @spec subnet_mask_to_prefix_length(:inet.ip_address()) ::
          {:ok, VintageNet.prefix_length()} | {:error, String.t()}
  def subnet_mask_to_prefix_length(subnet_mask) when tuple_size(subnet_mask) == 4 do
    # Not exactly efficient...
    lookup = for bits <- 0..32, into: %{}, do: {prefix_length_to_subnet_mask(:inet, bits), bits}

    case Map.get(lookup, subnet_mask) do
      nil -> {:error, "#{inspect(subnet_mask)} is not a valid IPv4 subnet mask"}
      bits -> {:ok, bits}
    end
  end

  def subnet_mask_to_prefix_length(subnet_mask) when tuple_size(subnet_mask) == 8 do
    # Not exactly efficient...
    lookup = for bits <- 0..128, into: %{}, do: {prefix_length_to_subnet_mask(:inet6, bits), bits}

    case Map.get(lookup, subnet_mask) do
      nil -> {:error, "#{inspect(subnet_mask)} is not a valid IPv6 subnet mask"}
      bits -> {:ok, bits}
    end
  end

  @doc """
  Convert an IPv4 or IPv6 prefix length to a subnet mask.

  Examples:

      iex> VintageNet.IP.prefix_length_to_subnet_mask(:inet, 24)
      {255, 255, 255, 0}

      iex> VintageNet.IP.prefix_length_to_subnet_mask(:inet, 28)
      {255, 255, 255, 240}

      iex> VintageNet.IP.prefix_length_to_subnet_mask(:inet6, 64)
      {65535, 65535, 65535, 65535, 0, 0, 0, 0}
  """
  @spec prefix_length_to_subnet_mask(:inet | :inet6, VintageNet.prefix_length()) ::
          :inet.ip_address()
  def prefix_length_to_subnet_mask(:inet, len) when len >= 0 and len <= 32 do
    rest = 32 - len
    <<a, b, c, d>> = <<-1::size(len), 0::size(rest)>>
    {a, b, c, d}
  end

  def prefix_length_to_subnet_mask(:inet6, len) when len >= 0 and len <= 128 do
    rest = 128 - len

    <<a::size(16), b::size(16), c::size(16), d::size(16), e::size(16), f::size(16), g::size(16),
      h::size(16)>> = <<-1::size(len), 0::size(rest)>>

    {a, b, c, d, e, f, g, h}
  end

  @doc """
  Utility function to trim an IP address to its subnet

  Examples:

      iex> VintageNet.IP.to_subnet({192, 168, 1, 50}, 24)
      {192, 168, 1, 0}

      iex> VintageNet.IP.to_subnet({192, 168, 255, 50}, 22)
      {192, 168, 252, 0}

      iex> VintageNet.IP.to_subnet({64768, 43690, 0, 0, 4144, 58623, 65276, 33158}, 64)
      {64768, 43690, 0, 0, 0, 0, 0, 0}
  """
  @spec to_subnet(:inet.ip_address(), VintageNet.prefix_length()) :: :inet.ip_address()
  def to_subnet({a, b, c, d}, subnet_bits) when subnet_bits >= 0 and subnet_bits <= 32 do
    not_subnet_bits = 32 - subnet_bits
    <<subnet::size(subnet_bits), _::size(not_subnet_bits)>> = <<a, b, c, d>>
    <<new_a, new_b, new_c, new_d>> = <<subnet::size(subnet_bits), 0::size(not_subnet_bits)>>
    {new_a, new_b, new_c, new_d}
  end

  def to_subnet({a, b, c, d, e, f, g, h}, subnet_bits)
      when subnet_bits >= 0 and subnet_bits <= 128 do
    not_subnet_bits = 128 - subnet_bits

    <<subnet::size(subnet_bits), _::size(not_subnet_bits)>> =
      <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>

    <<new_a::16, new_b::16, new_c::16, new_d::16, new_e::16, new_f::16, new_g::16, new_h::16>> =
      <<subnet::size(subnet_bits), 0::size(not_subnet_bits)>>

    {new_a, new_b, new_c, new_d, new_e, new_f, new_g, new_h}
  end

  @doc """
  Return the IPv4 broadcast address for the specified subnet and prefix

  Examples:

      iex> VintageNet.IP.ipv4_broadcast_address({192, 168, 1, 50}, 24)
      {192, 168, 1, 255}

      iex> VintageNet.IP.ipv4_broadcast_address({74, 125, 227, 0}, 29)
      {74, 125, 227, 7}
  """
  @spec ipv4_broadcast_address(:inet.ip4_address(), VintageNet.prefix_length()) ::
          :inet.ip4_address()
  def ipv4_broadcast_address({a, b, c, d}, subnet_bits)
      when subnet_bits >= 0 and subnet_bits <= 32 do
    not_subnet_bits = 32 - subnet_bits
    <<subnet::size(subnet_bits), _::size(not_subnet_bits)>> = <<a, b, c, d>>
    <<new_a, new_b, new_c, new_d>> = <<subnet::size(subnet_bits), -1::size(not_subnet_bits)>>
    {new_a, new_b, new_c, new_d}
  end
end
