# Fresh state
File.rm_rf!("test/tmp")

# VintageNet.InterfacesMonitor only works on Linux
exclude = if :os.type() == {:unix, :linux}, do: [], else: [requires_interfaces_monitor: true]

# Networking support has enough pieces that are singleton in nature
# that parallel running of tests can't be done.
ExUnit.start(exclude: exclude, max_cases: 1)
