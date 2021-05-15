# Fresh state
File.rm_rf!("test/tmp")

# Always warning as errors
if Version.match?(System.version(), "~> 1.10") do
  Code.put_compiler_option(:warnings_as_errors, true)
end

# VintageNet.InterfacesMonitor only works on Linux
exclude = if :os.type() == {:unix, :linux}, do: [], else: [requires_interfaces_monitor: true]

# Networking support has enough pieces that are singleton in nature
# that parallel running of tests can't be done.
ExUnit.start(exclude: exclude, max_cases: 1)
