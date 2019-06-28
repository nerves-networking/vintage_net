# Changelog

## v0.3.1

* New features
  * Add null persistence implementation for devices migrating from Nerves
    Network that already have a persistence strategy in place

## v0.3.0

* New features
  * Support the `busybox` hex.pm package to bring in networking support if not
    present in the Nerves system image. This enables use with the minimal
    official Nerves images.
  * Add Unix domain socket interface to the `wpa_supplicant`. This enables
    much faster scanning of WiFi networks and other things like collecting
    attached clients when in AP-mode and pinging the supplicant to make sure
    it's running.
  * Log output of commandline-run applications so that error messages don't get
    lost.
  * Provide utilities for reporting WiFi signal strength as a percent to end
    users.

* Bug fixes
  * Support scanning WiFi access points with Unicode names (emoji, etc. in their
    SSIDs)
  * Allow internet connectivity pings to be missed 3 times in a row before
    deciding that the internet isn't reachable. This avoids transients due to
    the random dropped packet.
  * Reduce externally visible transients due to internal GenServers crashing and
    restarting - also addressed the crashes
  * Support configure while configuring - let's you cancel a configuration that
    takes a long time to apply and apply a new one

## v0.2.4

* New features
  * Listen for interface additions and physical layer notifications so that
    routing and status updates can be made much more quickly
  * Add `lower_up` to the interface properties

## v0.2.3

* Bug fixes
  * This release fixes supervision issues so that internal VintageNet crashes
    can be recovered
  * `VintageNet.get_configuration/1` works now
  * `"available_interfaces"` is updated again

## v0.2.2

* Bug fixes
  * Fix local LAN routing

## v0.2.1

* New features
  * Expose summary status of whether the whole device is
    disconnected, LAN-connected, or Internet-connected

## v0.2.0

* New features
  * Support WiFi AP mode - see README.md for example

* Bug fixes
  * Alway update local routes before default routes to avoid getting errors when
    Linux detects an unroutable table entry

## v0.1.0

Initial release to hex.
