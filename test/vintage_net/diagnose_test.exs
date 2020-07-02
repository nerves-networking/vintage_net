defmodule VintageNet.DiagnoseTest do
  use VintageNetTest.Case
  alias VintageNet.Diagnose

  doctest Diagnose

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  setup do
    # Capture Application exited logs
    capture_log(fn ->
      Application.stop(:vintage_net)
      Application.start(:vintage_net)
    end)

    # Remove persisted files if anything hung around
    on_exit(fn ->
      File.rm(Path.join(Application.get_env(:vintage_net, :persistence_dir), "eth0"))
      File.rm(Path.join(Application.get_env(:vintage_net, :persistence_dir), "wlan0"))
    end)

    :ok
  end

  test "asdfasdf" do
    capture_log(fn ->
      :ok =
        VintageNet.configure("testifname", %{
          type: VintageNetTest.TestTechnology
        })

      # configure/2 is asynchronous, so wait for the interface to appear.
      Process.sleep(100)
      assert ["testifname"] == VintageNet.configured_interfaces()
    end)

    output = capture_io(&Diagnose.run_diagnostics/0)
    assert output =~ "Interface testifname\n  Configured but not detected\n"
  end
end
