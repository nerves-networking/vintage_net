defmodule VintageNet.PowerManager.StateMachineTest do
  use ExUnit.Case

  alias VintageNet.PowerManager.StateMachine

  doctest StateMachine

  test "normal flow" do
    sm = StateMachine.init()

    {sm, actions} = StateMachine.power_on(sm)
    assert actions == [:power_on]
    assert sm == :on_hold

    # on hold timer expires normally
    {sm, actions} = StateMachine.timeout(sm)
    assert actions == [:start_watchdog_timer]

    # pet watchdog a few times and check that watchdog timer is restarted
    {sm, actions} = StateMachine.pet_watchdog(sm)
    assert actions == [:start_watchdog_timer]
    {sm, actions} = StateMachine.pet_watchdog(sm)
    assert actions == [:start_watchdog_timer]
    {sm, actions} = StateMachine.pet_watchdog(sm)
    assert actions == [:start_watchdog_timer]

    # normal power off
    {sm, actions} = StateMachine.power_off(sm)
    assert actions == [:start_transient_timer]
    {sm, actions} = StateMachine.timeout(sm)
    assert actions == [:start_powering_off]

    # poweroff timer expires normally
    {_sm, actions} = StateMachine.timeout(sm)
    assert actions == [:power_off]
  end

  test "immediate power off waits the minimum on time" do
    sm = StateMachine.init()

    {sm, actions} = StateMachine.power_on(sm)
    assert actions == [:power_on]

    # Power off right after a power on doesn't do anything
    {sm, actions} = StateMachine.power_off(sm)
    assert actions == []

    # Hold time expires so power off should happen now
    {_sm, actions} = StateMachine.timeout(sm)
    assert actions == [:start_powering_off]
  end

  test "watchdog timeout does a reset" do
    # Normal startup sequence
    sm = StateMachine.init()
    {sm, actions} = StateMachine.power_on(sm)
    assert actions == [:power_on]
    {sm, actions} = StateMachine.timeout(sm)
    assert actions == [:start_watchdog_timer]

    # Watchdog timeout
    {sm, actions} = StateMachine.timeout(sm)
    assert actions == [:start_powering_off]

    # Late petting of the watchdog ignored
    {sm, actions} = StateMachine.pet_watchdog(sm)
    assert actions == []

    # Calling power_on after it's too late can't stop the reset
    {sm, actions} = StateMachine.power_on(sm)
    assert actions == []

    # poweroff timer expires normally
    {sm, actions} = StateMachine.timeout(sm)
    assert actions == [:power_off]
    # hold in poweroff timer expires normally
    {sm, actions} = StateMachine.timeout(sm)
    assert actions == [:power_on]

    # power on timer expires normally
    {_sm, actions} = StateMachine.timeout(sm)
    assert actions == [:start_watchdog_timer]
  end

  test "transient power off/power on handled" do
    # Normal startup sequence
    sm = StateMachine.init()
    {sm, actions} = StateMachine.power_on(sm)
    assert actions == [:power_on]
    {sm, actions} = StateMachine.timeout(sm)
    assert actions == [:start_watchdog_timer]

    # Power off
    {sm, actions} = StateMachine.power_off(sm)
    assert actions == [:start_transient_timer]
    # Change mind - power on (nothing happens)
    {sm, actions} = StateMachine.power_on(sm)
    assert actions == []

    # Transient timer timeout (nothing happens)
    {_sm, actions} = StateMachine.timeout(sm)
    assert actions == [:start_watchdog_timer]
  end

  test "can't power back on immediately" do
    # Normal startup sequence
    sm = StateMachine.init()
    {sm, actions} = StateMachine.power_on(sm)
    assert actions == [:power_on]
    {sm, actions} = StateMachine.timeout(sm)
    assert actions == [:start_watchdog_timer]

    # Power off and get past transient detection
    {sm, actions} = StateMachine.power_off(sm)
    assert actions == [:start_transient_timer]
    {sm, actions} = StateMachine.timeout(sm)
    assert actions == [:start_powering_off]
    {sm, actions} = StateMachine.timeout(sm)
    assert actions == [:power_off]

    # Try powering on immediately - nothing should happen
    {sm, actions} = StateMachine.power_on(sm)
    assert actions == []

    # Min power off timer expires so it's ok to start again
    {_sm, actions} = StateMachine.timeout(sm)
    assert actions == [:power_on]
  end

  test "can force a reset when on" do
    sm = StateMachine.init()
    # Reset doesn't do anything when off
    {sm, actions} = StateMachine.force_reset(sm)
    assert actions == []

    # Normal startup sequence
    {sm, actions} = StateMachine.power_on(sm)
    assert actions == [:power_on]
    {sm, actions} = StateMachine.timeout(sm)
    assert actions == [:start_watchdog_timer]

    # Reset now!
    {sm, actions} = StateMachine.force_reset(sm)
    assert actions == [:start_powering_off]

    # Reset doesn't do anything when powering off
    {sm, actions} = StateMachine.force_reset(sm)
    assert actions == []

    # poweroff timer expires normally
    {sm, actions} = StateMachine.timeout(sm)
    assert actions == [:power_off]

    # Reset doesn't do anything when off
    {sm, actions} = StateMachine.force_reset(sm)
    assert actions == []

    # hold in poweroff timer expires normally and powers up
    {_sm, actions} = StateMachine.timeout(sm)
    assert actions == [:power_on]
  end

  test "state information" do
    sm = StateMachine.init()
    assert StateMachine.info(sm, 0) == "Off"

    {sm, _actions} = StateMachine.power_on(sm)
    assert StateMachine.info(sm, 10) == "Starting up/on (10 ms left)"

    # on hold timer expires normally
    {sm, _actions} = StateMachine.timeout(sm)
    assert StateMachine.info(sm, 10) == "On (watchdog timeout in 10 ms)"

    # normal power off
    {sm, _actions} = StateMachine.power_off(sm)
    assert StateMachine.info(sm, 10) == "Waiting to power off (10 ms left)"
    {sm, _actions} = StateMachine.timeout(sm)
    assert StateMachine.info(sm, 10) == "Power off done in 10 ms"

    # poweroff timer expires normally
    {sm, _actions} = StateMachine.timeout(sm)
    assert StateMachine.info(sm, 10) == "Off (OK to power on in 10 ms)"
  end
end
