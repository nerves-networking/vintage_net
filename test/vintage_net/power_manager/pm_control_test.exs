defmodule VintageNet.PowerManager.PMControlTest do
  use VintageNetTest.Case

  alias VintageNet.PowerManager.PMControl
  alias VintageNetTest.TestPowerManager, as: TPM

  import ExUnit.CaptureLog

  @test_ifname "test0"

  setup do
    # Restart the VintageNet application, so all of the tests
    # can be in a pristine and consistent configuration.
    #
    # No interfaces are started so that the InterfaceManager
    # does not interfere with testing the PowerManager. This
    # means that the only calls to reset and power off hardware
    # come from here.
    #
    # Note that the set of tests here are spot checks. The bulk
    # of the interesting tests are in StateMachineTest.
    capture_log(fn ->
      Application.stop(:vintage_net)

      # Just in case another test failed and didn't clean up...
      File.rm_rf!(Application.get_env(:vintage_net, :persistence_dir))

      Application.start(:vintage_net)
    end)

    # Restore the configuration and persistance state to the original way
    on_exit(fn ->
      capture_log(fn ->
        Application.stop(:vintage_net)
        Application.start(:vintage_net)
      end)
    end)

    :ok
  end

  test "unmanaged interfaces don't have state" do
    assert {:error, _reason} = TPM.get_state("bogus2")
  end

  test "unmanaged interfaces return errors when getting info" do
    assert :error = PMControl.info("bogus3")
  end

  test "normal path" do
    output =
      capture_log(fn ->
        assert pm_state() == :off

        assert TPM.call_count(@test_ifname, :power_on) == 0
        PMControl.power_on(@test_ifname)
        assert TPM.call_count(@test_ifname, :power_on) == 1

        assert pm_state() == :on

        # Wait for power on hold time (50 ms) to pass
        Process.sleep(60)

        # Pet the watch dog a few times.
        PMControl.pet_watchdog(@test_ifname)
        PMControl.pet_watchdog(@test_ifname)
        PMControl.pet_watchdog(@test_ifname)
        PMControl.pet_watchdog(@test_ifname)

        PMControl.power_off(@test_ifname)
        assert TPM.call_count(@test_ifname, :start_powering_off) == 0

        # Wait for transient power off/reset detection to pass (10 ms)
        Process.sleep(15)

        assert TPM.call_count(@test_ifname, :start_powering_off) == 1
        assert TPM.call_count(@test_ifname, :power_off) == 0
        assert pm_state() == :powering_off

        # Wait for final power off call (100 ms after start_powering_off)
        Process.sleep(105)
        assert TPM.call_count(@test_ifname, :power_off) == 1
        assert pm_state() == :off
      end)

    # Verify that there's logging
    assert output =~ "PMControl(test0): Powering on"
    assert output =~ "PMControl(test0): Start powering off"
    assert output =~ "PMControl(test0): Complete power off"
  end

  test "handle_info" do
    assert TPM.last_handle_info(@test_ifname) == nil

    PMControl.send_message(@test_ifname, :this_is_a_test)

    Process.sleep(5)
    assert TPM.last_handle_info(@test_ifname) == :this_is_a_test
  end

  test "power manager that crashes" do
    output =
      capture_log(fn ->
        {:ok, result} = PMControl.info("bad_power0")
        assert result.pm_state == :off

        PMControl.power_on("bad_power0")
        Process.sleep(50)
        # The failure should log a message (checked later) and fail
        # the GenServer. It will be restarted and power will remain
        # off.
        {:ok, result} = PMControl.info("bad_power0")
        assert result.pm_state == :off
      end)

    # Verify that there's logging
    assert output =~ "PMControl(bad_power0): Powering on"

    assert output =~
             "PMControl(bad_power0): callback power_on raised :error, %RuntimeError{message: \"oops\"}"
  end

  test "not petting the watch dog causes a reset" do
    output =
      capture_log(fn ->
        assert pm_state() == :off

        assert TPM.call_count(@test_ifname, :power_on) == 0
        PMControl.power_on(@test_ifname)
        assert TPM.call_count(@test_ifname, :power_on) == 1

        assert pm_state() == :on

        # Wait for power on hold time (50 ms)
        Process.sleep(60)

        assert TPM.call_count(@test_ifname, :start_powering_off) == 0

        # Wait for watchdog timer to expire (50 ms)
        Process.sleep(60)

        assert TPM.call_count(@test_ifname, :start_powering_off) == 1
        assert TPM.call_count(@test_ifname, :power_off) == 0
        assert pm_state() == :powering_off

        # Wait for final power off call and min off time (100 ms after start_powering_off)
        Process.sleep(100)
        assert TPM.call_count(@test_ifname, :power_off) == 1
        assert TPM.call_count(@test_ifname, :power_on) == 2
        assert pm_state() == :on
      end)

    # Verify that there's logging
    assert output =~ "PMControl(test0): Powering on"
    assert output =~ "PMControl(test0): Start powering off"
    assert output =~ "PMControl(test0): Complete power off"
  end

  defp pm_state() do
    case PMControl.info(@test_ifname) do
      {:ok, info} -> info.pm_state
      :error -> :error
    end
  end
end
