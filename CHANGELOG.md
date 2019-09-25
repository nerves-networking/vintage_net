# Changelog

## v0.6.0

IMPORTANT: This release contains a LOT of changes. VintageNet is still pre-1.0
and we're actively making API changes as we gain real world experience with it.
Please upgrade carefully.

* Incompatible changes
  * All IP addresses are represented as tuples. You can still specify IP
    addresses as strings, like "192.168.1.1", but it will be converted to tuple
    form. When you `get` the configuration, you'll see IP addresses as tuples.
    This means that if you save your configuration and revert to a previous
    version of VintageNet, the settings won't work.
  * WiFi network configuration is always under the `:networks` key. This was
    inconsistent. Configuration normalization will update old saved
    configurations.
  * Support for the IPv4 broadcast IP address has been removed. Existing support
    was incomplete and slightly confusing, so we decided to remove it for now.
  * All IP address subnets are represented by their prefix length. For example,
    255.255.255.0 is recorded as a subnet with prefix length 24. Configuration
    normalization converts subnet masks to prefix length now.

* New features
  * USB gadget support - See `VintageNet.Technology.Gadget`. It is highly likely
    that we'll refactor USB gadget support to its own project in the future.
  * Add `:verbose` key to configs for enabling debug messages from third party
    applications. Currently `:verbose` controls debug output from
    `wpa_supplicant`.
  * Allow users to pass additional options to `MuonTrap` so that it's possible
    to run network daemons in cgroups (among other things)

* Bug fixes
  * Networking daemons should all be supervised now. For example, `udhcpc`
    previously was started by `ifup` and under many conditions, it was possible
    to get numerous instances started simultaneously. Plus failures weren't
    detected.
  * No more `killall` calls to cleanup state. This had prevented network
    technologies from being used on multiple interfaces.
  * No more `ifupdown`. This was very convenient for getting started, but has
    numerous flaws. Search the Internet for rants. This was replaced with direct
    calls to `ip link` and `ip addr` and adding network daemons to supervision
    trees.

* Known issues
  * Static IP addressing is still not implemented. It's only implemented enough
    for WiFi AP mode and USB gadget mode to work. We hope to fix this soon.
  * It's not possible to temporarily configure network settings. At the moment,
    if persistence is enabled (the default), configuration updates are always
    saved.

## v0.5.1

* Bug fixes
  * Add missing PSK conversion when configuring multiple WiFi networks. This
    fixes a bug where backup networks wouldn't connect.

* Improvements
  * Don't poll WiFi networks that are configured for AP mode for Internet. They
    will never have it.
  * Reduce the number of calls to update routing tables. Previously they were
    unnecessarily updated on DHCP failures due to timeouts. This also removes
    quite a bit of noise from the log.
  * Filter out interfaces with "Null" technologies on them from the configured
    list. They really aren't configured so it was confusing to see them.

## v0.5.0

Backwards incompatible change: The WiFi access point property (e.g.,
["interfaces", "wlan0", "access_points"]) is now a simple list of access point
structs. It was formerly a map and code using this property will need to be
updated.

## v0.4.1

* Improvements
  * Support run-time configuration of regulatory domain
  * Error message improvement if build system is missing pkg-config

## v0.4.0

Build note: The fix to support AP scanning when in AP-mode (see below) required
pulling in libnl-3. All official Nerves systems have it installed since it is
required by the wpa_supplicant. If you're doing host builds on Linux, you'll
need to run `apt install libnl-genl-3-dev`.

* New features
  * Report IP addresses in the interface properties. It's now possible to listen
    for IP address changes on interfaces. IPv4 and IPv6 addresses are reported.
  * Support scanning for WiFi networks when an WiFi module is in AP mode. This
    lets you make WiFi configuration wizards. See the vintage_net_wizard
    project.
  * Add interface MAC addresses to the interface properties

* Bug fixes
  * Some WiFi adapters didn't work in AP mode since their drivers didn't support
    the P2P interface. Raspberry Pis all support the P2P interface, but some USB
    WiFi dongles do not. The wpa_supplicant interface code was updated to use
    fallback to the non-P2P interface in AP mode if it wasn't available.

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
