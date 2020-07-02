defmodule VintageNet.Diagnose do
  @moduledoc false

  alias VintageNet.Info
  alias VintageNet.Technology.SystemCheck
  import IEx, only: [dont_display_result: 0]

  @doc "Print diagnostic info"
  @spec run_diagnostics(opts :: nil | Keyword.t()) :: :"do not show this result in output"
  def run_diagnostics(opts \\ nil) do
    opts = opts || Application.get_all_env(:vintage_net)
    available = VintageNet.all_interfaces()
    configured = VintageNet.configured_interfaces()
    unconfigured = available -- configured

    IO.write("""
    Unconfigured interfaces: #{inspect(unconfigured)}
    """)

    # For each interface with a configuration
    # Report whether the interface is detected or not
    #   If detected, report connection status
    Enum.map(configured, fn ifname ->
      %{type: type} = VintageNet.get_configuration(ifname)
      check_system_result = type.check_system(opts)

      if ifname in available do
        [
          "\nInterface ",
          ifname,
          "\n",
          format_check_system(check_system_result),
          Info.format_if_attribute(ifname, "type", "Type"),
          Info.format_if_attribute(ifname, "state", "State", true),
          Info.format_if_attribute(ifname, "connection", "Connection", true),
          "\n"
        ]
      else
        [
          "\nInterface ",
          ifname,
          IO.ANSI.yellow(),
          " [Configured but not detected] ",
          IO.ANSI.reset(),
          "\n\n",
          format_check_system(check_system_result),
          "  ",
          "\n"
        ]
      end
    end)
    |> IO.puts()

    dont_display_result()
  end

  @spec format_check_system(SystemCheck.t()) :: iodata()
  defp format_check_system(system_check) do
    errors =
      Enum.map(system_check.errors, fn error ->
        [
          IO.ANSI.red(),
          "[ERROR] ",
          error,
          IO.ANSI.reset(),
          "\n"
        ]
      end)

    warnings =
      Enum.map(system_check.warnings, fn warning ->
        [
          IO.ANSI.yellow(),
          "[WARN]  ",
          warning,
          IO.ANSI.reset(),
          "\n"
        ]
      end)

    [
      "System Check:\r\n",
      errors,
      warnings
    ]

    # errors = [
    #   "System Check Errors\n",
    #   IO.ANSI.red(),
    #   Enum.join(system_check.errors, "\n"),
    #   IO.ANSI.reset(),
    #   "\n"
    # ]
    # warnings = [
    #   "System Check Warnings\n",
    #   IO.ANSI.yellow(),
    #   Enum.join(system_check.warnings, "\n"),
    #   IO.ANSI.reset(),
    #   "\n"
    # ]

    # [
    #   errors,
    #   "\n",
    #   warnings
    # ]
  end
end
