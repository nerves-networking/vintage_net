defmodule VintageNet.Connectivity.DNSResolver do
  @moduledoc false

  # module for resolving domain names to ip addresses

  alias VintageNet.IP

  import Record, only: [defrecord: 2]

  @type hostent() :: record(:hostent, [])

  defrecord :hostent, Record.extract(:hostent, from_lib: "kernel/include/inet.hrl")

  @doc """
  Try to resolve a hosts ip addresses
  """
  @spec resolve(VintageNet.any_ip_address()) :: {:ok, hostent()} | {:error, :inet.posix()}
  def resolve(domain_name) when is_binary(domain_name) do
    case :inet.gethostbyname(String.to_charlist(domain_name)) do
      {:ok, hostent} ->
        {:ok, hostent}

      error ->
        error
    end
  end

  def resolve(ip_address) when is_tuple(ip_address) do
    ip_address
    |> IP.ip_to_string()
    |> resolve()
  end
end
