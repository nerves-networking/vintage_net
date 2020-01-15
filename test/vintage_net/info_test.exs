defmodule VintageNet.InfoTest do
  use VintageNetTest.Case
  alias VintageNet.Info

  doctest Info

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
    end)

    :ok
  end

  test "info sanitizes psk and password fields" do
    :ok =
      VintageNet.configure("eth0", %{
        type: VintageNetTest.TestTechnology,
        arbitrary_config_name: %{
          psk: "psk1",
          password: "password1"
        },
        list_of_arbitrary_configuration: [
          %{psk: "psk2", password: "password2"},
          %{psk: "psk3", password: "password3"}
        ]
      })

    # configure/2 is asynchronous, so wait for the interface to appear.
    Process.sleep(100)
    assert ["eth0"] == VintageNet.configured_interfaces()

    output = capture_io(&Info.info/0)
    refute output =~ "psk1"
    refute output =~ "psk2"
    refute output =~ "psk3"
    refute output =~ "password1"
    refute output =~ "password2"
    refute output =~ "password3"
  end

  test "info allows for not redacting" do
    :ok =
      VintageNet.configure("eth0", %{
        type: VintageNetTest.TestTechnology,
        arbitrary_config_name: %{
          psk: "psk1",
          password: "password1"
        },
        list_of_arbitrary_configuration: [
          %{psk: "psk2", password: "password2"},
          %{psk: "psk3", password: "password3"}
        ]
      })

    # configure/2 is asynchronous, so wait for the interface to appear.
    Process.sleep(100)
    assert ["eth0"] == VintageNet.configured_interfaces()

    output =
      capture_io(fn ->
        Info.info(redact: false)
      end)

    assert output =~ "psk1"
    assert output =~ "psk2"
    assert output =~ "psk3"
    assert output =~ "password1"
    assert output =~ "password2"
    assert output =~ "password3"
  end

  test "info works with nothing configured" do
    output = capture_io(&Info.info/0)

    assert output =~ "All interfaces"
    assert output =~ "Available interfaces"
    assert output =~ "No configured interfaces"
  end

  test "info works with a configured interface" do
    :ok = VintageNet.configure("eth0", %{type: VintageNetTest.TestTechnology})

    # configure/2 is asynchronous, so wait for the interface to appear.
    Process.sleep(100)
    assert ["eth0"] == VintageNet.configured_interfaces()

    output = capture_io(&Info.info/0)

    assert output =~ "All interfaces"
    assert output =~ "Available interfaces"
    assert output =~ "Interface eth0"
    assert output =~ "Type: VintageNetTest.TestTechnology"
  end
end
