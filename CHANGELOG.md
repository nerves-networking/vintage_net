# Changelog

## v0.10.3

* Bug fixes
  * Fix regression with tracking udhcpd lease notifications. Leases
    notifications were being ignored, so if you were monitoring leases to see
    who was connected, then you wouldn't see any connections without this fix.
    Thanks to Jon Thacker for reporting this issue.
  * Fix crashes when the application config is invalid. While the configurations
    were incorrect and needed to be fixed, it was harder to debug than it should
    have been. This release logs messages on invalid configs and carries on
    bringing up left that's valid. Thanks to Matt Ludwigs for this fix.

## v0.10.2

This release officially removes support for Elixir 1.7 and Elixir 1.8. It turns
out that those versions wouldn't have worked in v0.10.0 due to a dependency that
was added.

* Improvements
  * Add `VintageNet.reset_to_defaults/1` so that it's easy to reset a network
    interface's configuration to what it would be if `VintageNet.configure` had
    never been called. The previous "easy" way of doing this was to erase the
    persisted configuration file and reboot.
  * Clean up interface reachability handling (disconnected vs. lan-connected vs
    internet-connected). There was an issue where the status was out of sync due
    a bug in a technology implementation. This is harder to do now. IMPORTANT:
    if you have a custom technology implementation, calling
    `VintageNet.RouteManager.set_connection_status` is sufficient. You no
    longer need to update the status property for your interface. This is not a
    common need.

## v0.10.1

* Improvements
  * There's now an `:additional_name_servers` global configuration key so that
    it's possible to force name servers to always be in the list to use. For
    example, if you don't trust that you'll always get good name servers from
    DHCP, you can add a few public name servers to this list.
  * `/etc/resolv.conf` now has nice comments on where configuration items come
    from. Thanks to Connor Rigby for this idea and implementation.

## v0.10.0

This release is mostly backwards compatible. If you have created your own
VintageNet technology, you may need to update your unit tests. If you are an end
user of VintageNet, your code should continue to work unmodified.

* Improvements
  * The Internet connectivity check logic now supports a list of IP addresses
    instead of just one. The default has been updated to include major public
    DNS providers. The code checks them in succession until one responds. See
    `:internet_host_list` config key in the README.md if you need to change it.
  * Only start `udhcpc`/`udhcpd` when the network interface is up. This removes
    pointless attempts to get an IP address and their associated logs. It
    reduces connection time for wired Ethernet but doesn't affect WiFI.

* Bug fixes
  * Replace Crypto API calls that are no longer included with OTP 24.
  * Redact SAE passwords

## v0.9.3

* Bug fixes
  * Be more robust to `PowerManager.init/1` failures. While this function
    shouldn't raise, the effect of it raising was particularly destructive to
    VintageNet and took down networking.
  * Update `gen_state_machine` dependency to let the 3.0.0 release be used.

## v0.9.2

* Bug fixes
  * Handle missing commands as errors rather than raising. This makes it
    a little easier test `vintage_net` and libraries that use it.
  * Fixes `@doc` tag warnings during compile time

## v0.9.1

* Bug fixes
  * This fixes an issue where system networking binaries were not being resolved
    according to `vintage_net`'s view of the `PATH`. `vintage_net` looks in the
    standard directories by default, but it's possible to restrict or add
    locations.

## v0.9.0

This release contains improvements that will not affect you unless you are
using a custom `VintageNet.Technology` implementation.

* New features
  * Add power management support. This adds support for powering on and off
    network devices and also enables `VintageNet` to restart devices that are
    not working (if allowed). See `VintageNet.PowerManager` for details.

* Breaking changes
  * Paths to networking programs like `wpa_supplicant` are no longer passed as
    opts during configuration. I.e., `:bin_wpa_supplicant`, `:bin_ip`, etc. This
    was not a generally useful feature since it wasn't possible to include all
    possible programs. A future plan is to add support for verifying that
    networking programs exist before trying to configure an interface. Programs
    should be passed as strings now.
  * Support for the `:busybox` hex package has been removed. This was useful
    when networking programs were unavailable on a system, but all official
    Nerves systems have included them for the past year and `:busybox` required
    maintenance to keep working and up-to-date.

## v0.8.0

* New features
  * [Breaking change for technology implementors] Decouple the network interface
    name from the one a network technology uses. For example, cellular modems
    can now have `vintage_net` wait for `wwan0` to appear before setting up a
    PPP interface (like `ppp0`). All network technology implementations need to
    be updated to provide `RawConfigs` that list the network interfaces they
    need to start. This is hard to miss since you'll get a compile error if it
    affects you.
  * Deterministic interface naming support - If you have a device with multiple
    network interfaces of the same type (e.g., multiple WiFi adapters) it is
    possible for them to switch between being assigned `wlan0` and `wlan1`
    under some conditions. This feature allows you to map their hardware
    location to a name of your choosing. See the `README.md` for details.
  * Add the "hw_path" property - For example, `{["interface", "eth0", "hw_path"], "/devices/platform/ocp/4a100000.ethernet"}`

* Bug fixes
  * Stop network interface management `GenServers` before running the "down"
    commands. This is most noticeable in reduced log noise on network hiccups
    and device removals.

## v0.7.9

* Bug fixes
  * Fix IP address being reported for PPP connections. Previously, it was the
    remote end of the PPP connection rather than the local end.
  * Fix missing IPv6 address reports. Depending on when IPv6 addresses were set
    on network interfaces, they might not have been reported. Note that IPv6
    isn't officially supported by VintageNet yet.

## v0.7.8

* Improvements
  * Store an interface's configuration in the `["interface", ifname, "config"]`
    property. This makes it possible to subscribe to configuration changes (like
    any other property).
  * Print out IP addresses with `VintageNet.info/0`

* Bug fixes
  * Fixed `VintageNet.get_configuration/1` to return the configuration that will
    be applied even if it's not the configuration that's currently applied.
    The previous semantics would break code that made decisions based on the
    current configurations.

## v0.7.7

* Improvements
  * Added time-in-state to `VintageNet.info`. This lets you see if a connection
    has bounced at a glance without digging through the logs.

## v0.7.6

* Bug fixes
  * Ensure that `Technology.normalize/1` is always called. Previously, this
    wasn't guaranteed, and it could result in a surprise when an unnormalized
    configuration got saved.
  * Remove duplicate resolv.conf entries on multi-homed devices
  * Fix warnings found by Elixir 1.10

## v0.7.5

* Bug fixes
  * Fix routing table error when configuring multiple interfaces of the same
    type.
  * Fix `VintageNet.info` for when it's called before `vintage_net` is loaded.

## v0.7.4

* Bug fixes
  * Fix `VintageNet.info` crash when displaying AP mode configurations
  * Save configurations using the `:sync` flag to reduce the chance that they're
    lost on ungraceful power offs. I.e., people pulling the power cable after
    device configuration.

## v0.7.3

* Improvements
  * Scrub `VintageNet.info/0` output to avoid accidental disclosure of WiFi
    credentials
  * Support options to `deconfigure/2` to mirror those on `configure/2`
  * Prefix `udhcpc` logs with interface to more easily blame problematic
    networks
  * Support IPv4 /32 subnets
  * Various documentation fixes and improvements

## v0.7.2

* Bug fix
  * Remove noisy log message introduced in v0.7.1

## v0.7.1

This release fixes an issue where the Internet-connectivity checking code could
crash. It was automatically restarted, but that had a side effect of delaying a
report that the device was connected AND breaking `mdns_lite`. Both the crash
and the restart issue were fixed. The `mdns_lite` side effect was due to its
multicast group membership being lost so this would affect other multicast-using
code.

* Bug fixes
  * Fix `:timeout_value` crash in the `InternetConnectivityChecker`
  * Force clear IPv4 addresses when the DHCP notifies a deconfig event. This
    occurs on a restart and is quickly followed by a renew. However, if
    applications don't see this, bounce and don't register their multicast
    listeners on affected IPv4 address again, they'll lose the subscription.

* Improvements
  * Added check for `nerves_network` and `nerves_init_gadget`. If your project
    pulls these in, it will get a moderately friendly notice to remove them.

## v0.7.0

This release moves network technology implementations (WiFi, wired Ethernet,
etc.) into their own projects. This means that they can evolve at their own
pace. It also means that we're finally ready to support the
`VintageNet.Technology` behaviour as part of the public API so that VintageNet
users can add support for network technologies that we haven't gotten to yet.

IMPORTANT: This change is not backwards compatible. You will need to update
existing projects to bring in a new dependency. The runtime is backwards
compatible. I.e., If you have a networking configuration saved in VintageNet, it
will be updated on load. It won't be re-saved, so if you need to revert an
update, it will still work. The next save, though, will use the new naming.

If you're using `VintageNet.Technology.Gadget`, do the following:

1. Add `{:vintage_net_direct, "~> 0.7.0"}` to your `mix.exs` dependencies.
   You'll notice that references to "gadget" have been replaced with the word
   "direct". We think the new naming is more accurate.
2. Replace all references to `VintageNet.Technology.Gadget` in your code to
   `VintageNetDirect`. Be aware of aliases and configuration.
3. If you passed options when configuring the network, the `:gadget` key is
   now `:vintage_net_direct`. Most users don't pass options.

If you're using `VintageNet.Technology.Ethernet`, do the following:

1. Add `{:vintage_net_ethernet, "~> 0.7.0"}` to your `mix.exs` dependencies.
2. Replace all references to `VintageNet.Technology.Ethernet` in your code to
   `VintageNetEthernet`. Be aware of aliases and configuration.

If you're using `VintageNet.Technology.WiFi`, do the following:

1. Add `{:vintage_net_wifi, "~> 0.7.0"}` to your `mix.exs` dependencies.
2. Replace all references to `VintageNet.Technology.WiFi` in your code to
   `VintageNetWiFi`. Be aware of aliases and configuration. Also, the "F" is
   capital.
3. The `:wifi` key in the network configuration is now `:vintage_net_wifi`.

## v0.6.6

* Bug fixes
  * Fix warning from Dialyzer when making wild card subscriptions. Code was also
    added to more thoroughly validate properties paths to raise on subtle issues
    that won't do what the programmer intends.

* New features
  * Added `VintageNet.match/1` to support "gets" on properties using wildcards.

## v0.6.5

* New features
  * Support wild card subscriptions to properties. This makes it possible to
    subscribe to things like `["interface", :_, "addresses"]` where the `:_`
    indicates that any value in the second position should match. That
    particular subscription would send a message whenever an IP address anywhere
    gets added, changed, or removed.

## v0.6.4

* Improvements
  * Added the `["interface", ifname, "eap_status"]` property for EAP
    events. EAP is currently only supported on WiFi, but is anticipated for
    wired Ethernet too.

## v0.6.3

This release renames the WiFi mode names. The old names still work so it's a
backwards compatible update. The new names are `:ap` and `:infrastructure`
instead of `:host` and `:client`. These names match the mode names in the IEEE
specifications and usage elsewhere.

* New features
  * Support static IPv4 configurations for a default gateway and list of name
    resolvers. See `:gateway` and `:name_servers` parameters.
  * Support ad-hoc WiFi networking (IBSS mode)

## v0.6.2

* New features
  * Support running a simple DNS server on an interface. This was added for WiFi
    AP mode configuration and could be useful for other scenarios.
  * Support DHCP server response options
  * Support disabling configuration persistence on a per-call basis. This is for
    temporary configurations where a reboot should not preserve the setting. For
    example, `VintageNet.configure("wlan0", config, persist: false)`

## v0.6.1

* New features
  * Add a `current_ap` property for WiFi interfaces so that programs can get
    information about the currently associated access point
  * Support running a DHCP server on wired Ethernet interfaces
  * Expose `VintageNet.WiFi.WPA2.validate_passphrase/1` so that applications can
    reuse the WiFI passphrase validation logic. This logic follows IEEE Std
    802.11i-2004 and validates things like proper length and character set

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
    Linux detects a table entry that cannot be routed

## v0.1.0

Initial release to hex.
