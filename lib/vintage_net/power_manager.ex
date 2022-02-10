defmodule VintageNet.PowerManager do
  @moduledoc """
  This is a behaviour for implementing platform-specific power management.

  From VintageNet's point of view, network devices have the following
  lifecycle:

  ```
  off --->  on ---> powering-off ---> off
  ```

  Power management does not necessarily mean controlling the power. The end
  effect should be similar, since VintageNet will try to toggle the power off
  and on if the network interface doesn't seem to be working. For example,
  unloading the kernel module for the network device on "power off" and loading
  it on "power on" may have the desired effect of getting a network interface
  unstuck.

  When a device is "on", VintageNet expects to be regularly told that the
  device is working ok. Working ok is device dependent, but could be something
  like the device has transmitted and received data. If VintageNet is not told
  that the device is working for a long enough time, it will reset the device
  by powering it off and then back on again.

  VintageNet calls functions here based on how it wants to transition a device.
  VintageNet maintains the device's power status internally, so implementations
  can blindly do what VintageNet tells them too in most cases. Powering on and
  off can be asynchronous to these function calls. VintageNet uses the presence
  of the networking interface (like "wlan0") to determine when the device is
  really available for networking.

  The following timeouts are important to consider (in milliseconds):

  1. `time_to_power_off`
  2. `power_on_hold_time`
  3. `min_power_off_time`
  4. `watchdog_timeout`

  The `time_to_power_off` specifies the time in the `powering-off` state. This
  is the maximum time to allow for a graceful shutdown. VintageNet won't bother
  the device until that time has expired. That means that if there's a request
  to use the device, it will wait the `powering-off` time before calling
  `finish_power_off` and then it will power the device back on. Device app
  notes may have recommendations for this time.

  The `power_on_hold_time` specifies how much time a device should be in the
  `powered-on` state before it is ok to power off again. This allows devices
  some time to initialize and recover on their own.

  The `min_power_off_time` specifies how long the device should remain powered
  off before it is powered back on.

  Finally, `watchdog_timeout` specifies how long to wait between notifications
  that the device is ok. Code reports that a device is ok by calling
  `VintageNet.PowerManager.PMControl.pet_watchdog/1`.

  While normal Erlang supervision expects that it can restart processes
  immediately and without regard to how long they have been running, bad things
  can happen to hardware if too aggressively restarted. Devices also initialize
  asynchronously so it's hard to know when they're fully available and some
  flakiness may be naturally due to VintageNet not knowing how to wait for a
  component to finish initialization. Please review your network device's power
  management guidelines before too aggressively reducing hold times. Cellular
  devices, in particular, want to signal their disconnection from the network
  to the tower and flush any unsaved configuration changes to Flash before
  power removal.

  Here's an example for a cellular device with a reset line connected to it:

  * `power_on` - De-assert the reset line. Return a `power_on_hold_time` of 10
    minutes
  * `start_powering_off` - Open the UART and send the power down command to the
    modem. Return a `time_to_power_off` of 1 minute.
  * `power_off` - Assert the reset line and return that power shouldn't be turned
    back on for another 10 seconds.

  PowerManager implementation lifetimes are the same as VintageNet's. In other
  words, they start and end with VintageNet. This is unlike a network interface
  which runs only as its existence and configuration allow. As such, VintageNet
  needs to know about all PowerManager implementations in its application
  environment.  For example, add something like this to your `config.exs`:

  ```elixir
  config :vintage_net,
    power_managers: [{MyCellularPM, [ifname: "ppp0", watchdog_timeout: 60_000, reset_gpio: 123]}]
  ```

  Each tuple is the implementation's module name and init arguments. VintageNet
  requires `:ifname` to be set. If you're managing the power for an interface
  with a dynamic name, enable predictable interface naming with `VintageNet`
  and use that name. The `watchdog_timeout` parameter is optional and defaults
  to one minute.
  """

  @doc """
  Initialize state for managing the power to the specified interface

  This is called on start and if the power management GenServer restarts. It
  should not assume that hardware is powered down.

  IMPORTANT: VintageNet assumes that `init/1` runs quickly and succeeds. Errors
  and exceptions from calling `init/1` are handled by disabling the PowerManager.
  The reason is that VintageNet has no knowledge on how to recover and disabling
  a power manager was deemed less bad that having supervision tree failures
  propagate upwards to terminate VintageNet. Messages are logged if this does
  happen.
  """
  @callback init(args :: keyword()) :: {:ok, state :: any()}

  @doc """
  Power on the hardware for a network interface

  The function should turn on power rails, deassert reset lines, load kernel
  modules or do whatever else is necessary to make the interface show up in
  Linux.

  Failure handling is not supported by VintageNet yet, so if power up can fail
  and the right handling for that is to try again later, then this function
  should do that.

  It is ok for this function to return immediately. When the network interface
  appears, VintageNet will start trying to use it.

  The return tuple should include the number of milliseconds VintageNet should
  wait before trying to power down the module again. This value should be
  sufficiently large to avoid getting into loops where VintageNet gives up on a
  network interface before it has initialized. 10 minutes (600,000 milliseconds),
  for example, is a reasonable setting.
  """
  @callback power_on(state :: any()) ::
              {:ok, next_state :: any(), hold_time :: non_neg_integer()}

  @doc """
  Start powering off the hardware for a network interface

  This function should start a graceful shutdown of the network interface
  hardware.  It may return immediately. The return value specifies how long in
  milliseconds VintageNet should wait before calling `power_off/2`. The idea is
  that a graceful power off should be allowed some time to complete, but not
  forever.
  """
  @callback start_powering_off(state :: any()) ::
              {:ok, next_state :: any(), time_to_power_off :: non_neg_integer()}

  @doc """
  Power off the hardware

  This function should finish powering off the network interface hardware. Since
  this is called after the graceful power down should have completed, it should
  forcefully turn off the power to the hardware.

  The implementation also returns a time that power must remain off, in milliseconds.
  `power_on/1` won't be called until that time expires.
  """
  @callback power_off(state :: any()) ::
              {:ok, next_state :: any(), min_off_time :: non_neg_integer()}

  @doc """
  Handle other messages

  All unknown messages sent to the power management `GenServer` come here. This
  callback is similar to `c:GenServer.handle_info/2`.

  To receive your own messages here, send them to `self()` in code run in any
  of the other callbacks. Another option is to call
  `VintageNet.PowerManager.PMControl.send_message/2`
  """
  @callback handle_info(msg :: any(), state :: any()) :: {:noreply, new_state :: any()}
end
