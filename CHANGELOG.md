# Changelog

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
