defmodule VintageNet.Route.InterfaceInfo do
  alias VintageNet.Interface.Classification
  alias VintageNet.Route.Calculator

  defstruct default_gateway: nil,
            ip_subnets: [],
            interface_type: :unknown,
            status: :disconnected

  @type t :: %__MODULE__{
          default_gateway: :inet.ip_address() | nil,
          ip_subnets: [{:inet.ip_address(), Calculator.subnet_bits()}],
          interface_type: Classification.interface_type(),
          status: Classification.connection_status()
        }

  # @spec metric(InterfaceInfo.t(), [Classification.prioritization()]) :: :disabled | non_neg_integer()
  @spec metric(atom() | %{interface_type: binary(), status: :disconnected | :internet | :lan}, [
          {:_ | :ethernet | :local | :mobile | :unknown | :wifi,
           :_ | :disconnected | :internet | :lan}
        ]) :: :disabled | pos_integer()
  def metric(info, prioritization) do
    Classification.compute_metric(info.interface_type, info.status, prioritization)
  end
end
