defmodule VintageNet.Diagnose do
  @moduledoc false

  alias VintageNet.Info
  import IEx, only: [dont_display_result: 0]

  @doc "Print diagnostic info"
  @spec run_diagnostics() :: :"do not show this result in output"
  def run_diagnostics() do
    opts = Application.get_all_env(:vintage_net)
    available = VintageNet.all_interfaces()
    configured = VintageNet.configured_interfaces()
    unconfigured = available -- configured

    IO.write("""
    Unconfigured interfaces:       #{inspect(unconfigured)}
    """)

    # For each interface with a configuration
    # Report whether the interface is detected or not
    #   If detected, report connection status
    Enum.map(configured, fn ifname ->
      if ifname in available do
        %{type: type} = VintageNet.get_configuration(ifname)

        check_system_result =
          try do
            type.check_system(opts)
          catch
            _, reason ->
              {:error, inspect(reason)}
          end

        [
          "\nInterface ",
          ifname,
          "\n",
          Info.format_if_attribute(ifname, "type", "Type"),
          Info.format_if_attribute(ifname, "state", "State", true),
          Info.format_if_attribute(ifname, "connection", "Connection", true),
          "  System check results: #{inspect(check_system_result)}",
          "\n"
        ]
      else
        [
          "\nInterface ",
          ifname,
          "\n",
          "  Configured but not detected",
          "\n"
        ]
      end
    end)
    |> IO.puts()

    dont_display_result()
  end
end
