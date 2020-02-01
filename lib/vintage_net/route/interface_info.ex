defmodule VintageNet.Route.InterfaceInfo do
  alias VintageNet.Interface.Classification

  @moduledoc false

  defstruct default_gateway: nil,
            weight: 0,
            ip_subnets: [],
            interface_type: :unknown,
            status: :disconnected

  @type t :: %__MODULE__{
          default_gateway: :inet.ip_address() | nil,
          weight: Classification.weight(),
          ip_subnets: [{:inet.ip_address(), VintageNet.prefix_length()}],
          interface_type: Classification.interface_type(),
          status: Classification.connection_status()
        }

  # @spec metric(t(), [Classification.prioritization()]) :: :disabled | pos_integer()
  @spec metric(t(), [
          {:_ | :ethernet | :local | :mobile | :unknown | :wifi,
           :_ | :disconnected | :internet | :lan}
        ]) :: :disabled | pos_integer()
  def metric(info, prioritization) do
    Classification.compute_metric(info.interface_type, info.status, info.weight, prioritization)
  end
end
