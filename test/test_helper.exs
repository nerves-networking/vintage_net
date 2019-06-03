File.rm_rf!("test/tmp")

# VintageNet.InterfacesMonitor only works on Linux
exclude = if :os.type() == {:unix, :linux}, do: [], else: [requires_interfaces_monitor: true]

ExUnit.start(exclude: exclude)
