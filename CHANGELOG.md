# Changelog

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.13.5] - 2023-09-13

* Changed
  * Warn when setting default routes with IP addresses outside of the subnet
    rather than crashing. Thanks to Ben Murphy for this fix.
  * Bulletproof force clearing of IP addresses to avoid crashing unnecessarily
    during cleanup. This was a very rare case.

## [v0.13.4] - 2023-07-07

* Changed
  * VintageNet configurations are normalized on load now rather than on use.
    For various reasons, it's useful to support multiple ways of specifying
    network configurations, but internally VintageNet always converts to one way
    to simplify use. If you call `VintageNet.get_configuration/1` or
    `VintageNet.get/2` to look at the config, you'd see the original form and not
    the normalized one. Now you get the normalized one.
  * Add `:reason` to the `VintageNet.Technology.Null`. VintageNet uses `Null` to
    make network interfaces stay unconfigured when requested or when there's an
    error. The `:reason` key helps you know why rather than forcing you to dig
    through logs.

* Fixes
  * When reseting a network configuration to defaults, a settings file was
    written and immediately erased. That doesn't happen any more.

## [v0.13.3] - 2023-06-10

* Changed
  * Sort dhcpd options so their order doesn't change in configuration files made
    by OTP 26. This fixes regression test failures that expected the files to by
    the same. It shouldn't matter for real use, but it's nice that the files are
    deterministic just in case.
  * Ignore unexpected messages to the InterfacesMonitor. This fixes an
    unnecessary crash/restart that was seen. Errors are still logged.

## [v0.13.2] - 2023-05-15

* Changed
  * Always set IPv4 broadcast address for static IPv4 configurations. This fixes
    an issue where the default for subnet broadcast address was not the expected
    host all-ones address per RFC 922.
  * Prune out LAN addresses when trying to detect Internet connectivity. This
    fixes one way that the Internet checker could be tricked by a captive portal
    that resolves all DNS queries to its portal address.
  * Fix confusion with `:dhcpd` `:subnet` option. This maps to the subnet mask
    field when responding to DHCP requests. The word "subnet" was interpreted as
    a subnet which was incorrect for this. `:netmask` is now an alias and
    examples are fixed.

## [v0.13.1] - 2023-03-15

This release fixes deprecation warnings when using Elixir 1.15.

## [v0.13.0] - 2023-01-22

This release has a breaking change if you're using the `UdhcpcHandler`
behaviour. This should be a rare use case. Use the `"dhcp_options"` property
now.

* Changed
  * Add `"dhcp_options"` to interface properties. This lets applications use
    information provided by DHCP servers in an easy way. It removes the need to
    process events from `udhcpc` directly, and therefore, the `UdhcpcHandler`
    behaviour is now a private API and may be removed in the future.
  * Fix some references to `iodata` that should have been `chardata`.

## [v0.12.2] - 2022-08-04

* Changed
  * Add `VintageNet.info_as_ansidata/1`. This lets you get the same results as
    `VintageNet.info`, but in a way that's easy to put on a web page or send
    to a server, etc.
  * Support updating network configuration even when it can't be persisted.
    Previously if there was an error saving the configuration and `persist:
    true` (the default), the configuration wouldn't be applied. This turned
    out to be problematic when trying to get some devices fixed. Now the
    device won't have the right config on reboot, but it can be reached over
    the network to be fixed.

## [v0.12.1] - 2022-06-01

* Changed
  * The list of name servers that VintageNet uses when configuring the name
    resolve is now available by running `VintageNet.get(["name_servers"])`.

## [v0.12.0] - 2022-04-27

This release has two potentially breaking changes:

1. Elixir 1.11 is now the minimum supported Elixir version.
2. `VintageNet.PropertyTable` has been extracted to its own library and is now
   just `PropertyTable`. Most users did not use `VintageNet.PropertyTable`
   directly, but if you did, you'll need to update the references.

* Changed
  * Extract `VintageNet.PropertyTable` to its own library. Note that many
    improvements were made to PropertyTable including renaming functions for
    consistency and changing the events. Code was added to VintageNet to hide
    these changes for now. Longer term, we'll be making things more consistent,
    but the hope is that the PropertyTable changes are transparent to VintageNet
    users in this release.
  * Support specifying absolute paths to network configuration commands. While
    this is not preferred, it's useful in some scenarios.
  * Redact more kinds of secrets in `VintageNet.info`

## [v0.11.5] - 2022-02-18

* Changed
  * Fix a no function clause exception in the InternetChecker that could happen
    if no IP addresses were assigned to an interface.

## [v0.11.4] - 2021-12-20

* Changed
  * Internet connectivity checks can now take domain names. Previously only IP
    addresses were supported. This change lets you add your own servers to the
    list since those servers may be more reliable indicators of Internet access
    in highly firewalled locations. A section on this was added to the README.md
    with an example.

## [v0.11.3] - 2021-11-18

* Changed
  * Don't downgrade the connection status on DHCP renewals. Previously, if there
    was a DHCP renewal, the connection status could go from "Internet-connected"
    "LAN-connected". The logic was that IP address and router changes may make
    the Internet unreachible. The new logic is to assume that the device is
    still Internet-connected and let the connectivity checker downgrade the
    status should it be necessary. This not only removes a status hiccup, but
    also fixes a race between the connectivity checker upgrading the connection
    and the DHCP notification degrading it.
  * Improve the `VintageNet.info` error when the `:vintage_net` application
    stops.

## [v0.11.2] - 2021-10-25

* Added
  * Added `VintageNet.RouteManager.refresh_route_metrics/0` to recompute the
    routing table metrics. This is useful if you're supplying your own
    `:route_metric_fun` and something has changed to make it return a different
    prioritization. Thanks to @LostKobrakai for this feature.

## [v0.11.1] - 2021-10-01

* Changed
  * The DNS server ordering is more deterministic now. Global DNS servers are
    guaranteed to be listed first and in the order specified. VintageNet will
    also try to preserve the ordering of DNS servers learned through DHCP. This
    isn't always possible, though. This fixes a hard-to-find error where an
    a difference in DNS server orderings between to device locations led to
    different behavior.
  * Use `VintageNet.ConnectivityChecker.*` in VintageNet. The connectivity
    checker module change was half made in `v0.11.0`, but the old module name
    was kept in a couple places to avoid breaking unit tests in other VintageNet
    libraries. Now it's completely converted. This doesn't affect runtime. Code
    that references the previous names will still get deprecation warnings like
    in `v0.11.0`.

## [v0.11.0] - 2021-08-19

This release should be a safe update for most users. Many routing table and
internet connectivity check modules were updated, but the changes were primarily
in private APIs.

* Added
  * Support for detecting Internet connectivity on an interface passively by
    watching tx and rx stats on TCP sockets. For example, if you have a
    long-lived TCP connection (like for MQTT), the keepalive messages will
    bump tx and rx counters that will let VintageNet skip testing the connection
    for connectivity. This reduces traffic on metered connections.
  * Support for completely overriding route metric calculation. You can now
    specify a `:route_metric_fun` instead of using the `DefaultMetric`
    calculator for determining which network interface preferences.
  * VintageNet property change events now come with timestamps. These are useful
    for computing state durations and other time-based stats for events.

* Removed
  * Support for setting route prioritization order. This feature was more
    limiting that it originally looked. The new `:route_metric_fun` is more
    straightforward since it lets you explicitly specify orderings and lets
    decisions be made based on more input data.

* Changed
  * `VintageNet.Interface.InternetConnectivityChecker` is now
    `VintageNet.Connectivity.InternetChecker`. Please update any references. Old
    references will continue to work, but give a deprecation message at runtime.

## [v0.10.5] - 2021-07-12

This release only contains build system and hex package update. It doesn't
change any code and is a safe update.

## [v0.10.4] - 2021-07-06

* Fixed
  * DHCP renewals would bounce connection status from :internet to :lan and back
    even when the IP address, subnet, and default gateway didn't change. This
    could cause a network connectivity hiccup that would happen every 24 hours
    (a common DHCP lease time). A fix was added to assume internet connectivity
    was maintained if the DHCP renewal didn't change IP parameters.

## [v0.10.3] - 2021-06-22

* Fixed
  * Fix regression with tracking udhcpd lease notifications. Leases
    notifications were being ignored, so if you were monitoring leases to see
    who was connected, then you wouldn't see any connections without this fix.
    Thanks to Jon Thacker for reporting this issue.
  * Fix crashes when the application config is invalid. While the configurations
    were incorrect and needed to be fixed, it was harder to debug than it should
    have been. This release logs messages on invalid configs and carries on
    bringing up left that's valid. Thanks to Matt Ludwigs for this fix.

## [v0.10.2] - 2021-05-20

This release officially removes support for Elixir 1.7 and Elixir 1.8. It turns
out that those versions wouldn't have worked in v0.10.0 due to a dependency that
was added.

* Added
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

## [v0.10.1] - 2021-05-06

* Added
  * There's now an `:additional_name_servers` global configuration key so that
    it's possible to force name servers to always be in the list to use. For
    example, if you don't trust that you'll always get good name servers from
    DHCP, you can add a few public name servers to this list.
  * `/etc/resolv.conf` now has nice comments on where configuration items come
    from. Thanks to Connor Rigby for this idea and implementation.

## [v0.10.0] - 2021-04-06

This release is mostly backwards compatible. If you have created your own
VintageNet technology, you may need to update your unit tests. If you are an end
user of VintageNet, your code should continue to work unmodified.

* Added
  * The Internet connectivity check logic now supports a list of IP addresses
    instead of just one. The default has been updated to include major public
    DNS providers. The code checks them in succession until one responds. See
    `:internet_host_list` config key in the README.md if you need to change it.
  * Only start `udhcpc`/`udhcpd` when the network interface is up. This removes
    pointless attempts to get an IP address and their associated logs. It
    reduces connection time for wired Ethernet but doesn't affect WiFI.

* Fixed
  * Replace Crypto API calls that are no longer included with OTP 24.
  * Redact SAE passwords

## [v0.9.3] - 2021-02-03

* Fixed
  * Be more robust to `PowerManager.init/1` failures. While this function
    shouldn't raise, the effect of it raising was particularly destructive to
    VintageNet and took down networking.
  * Update `gen_state_machine` dependency to let the 3.0.0 release be used.

## [v0.9.2] - 2020-10-10

* Fixed
  * Handle missing commands as errors rather than raising. This makes it
    a little easier test `vintage_net` and libraries that use it.
  * Fixes `@doc` tag warnings during compile time

## [v0.9.1] - 2020-07-29

* Fixed
  * This fixes an issue where system networking binaries were not being resolved
    according to `vintage_net`'s view of the `PATH`. `vintage_net` looks in the
    standard directories by default, but it's possible to restrict or add
    locations.

## [v0.9.0] - 2021-07-24

This release contains improvements that will not affect you unless you are
using a custom `VintageNet.Technology` implementation.

* Added
  * Add power management support. This adds support for powering on and off
    network devices and also enables `VintageNet` to restart devices that are
    not working (if allowed). See `VintageNet.PowerManager` for details.

* Changed
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

## [v0.8.0] - 2020-05-29

* Added
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

* Fixed
  * Stop network interface management `GenServers` before running the "down"
    commands. This is most noticeable in reduced log noise on network hiccups
    and device removals.

## [v0.7.9] - 2020-04-07

* Fixed
  * Fix IP address being reported for PPP connections. Previously, it was the
    remote end of the PPP connection rather than the local end.
  * Fix missing IPv6 address reports. Depending on when IPv6 addresses were set
    on network interfaces, they might not have been reported. Note that IPv6
    isn't officially supported by VintageNet yet.

## [v0.7.8] - 2020-04-03

* Added
  * Store an interface's configuration in the `["interface", ifname, "config"]`
    property. This makes it possible to subscribe to configuration changes (like
    any other property).
  * Print out IP addresses with `VintageNet.info/0`

* Fixed
  * Fixed `VintageNet.get_configuration/1` to return the configuration that will
    be applied even if it's not the configuration that's currently applied.
    The previous semantics would break code that made decisions based on the
    current configurations.

## [v0.7.7] - 2020-03-23

* Added
  * Added time-in-state to `VintageNet.info`. This lets you see if a connection
    has bounced at a glance without digging through the logs.

## [v0.7.6] - 2020-03-18

* Fixed
  * Ensure that `Technology.normalize/1` is always called. Previously, this
    wasn't guaranteed, and it could result in a surprise when an unnormalized
    configuration got saved.
  * Remove duplicate resolv.conf entries on multi-homed devices
  * Fix warnings found by Elixir 1.10

## [v0.7.5] - 2020-02-10

* Fixed
  * Fix routing table error when configuring multiple interfaces of the same
    type.
  * Fix `VintageNet.info` for when it's called before `vintage_net` is loaded.

## [v0.7.4] - 2020-01-22

* Fixed
  * Fix `VintageNet.info` crash when displaying AP mode configurations
  * Save configurations using the `:sync` flag to reduce the chance that they're
    lost on ungraceful power offs. I.e., people pulling the power cable after
    device configuration.

## [v0.7.3] - 2020-01-21

* Added
  * Scrub `VintageNet.info/0` output to avoid accidental disclosure of WiFi
    credentials
  * Support options to `deconfigure/2` to mirror those on `configure/2`
  * Prefix `udhcpc` logs with interface to more easily blame problematic
    networks
  * Support IPv4 /32 subnets
  * Various documentation fixes and improvements

## [v0.7.2] - 2019-12-20

* Bug fix
  * Remove noisy log message introduced in v0.7.1

## [v0.7.1] - 2019-12-20

This release fixes an issue where the Internet-connectivity checking code could
crash. It was automatically restarted, but that had a side effect of delaying a
report that the device was connected AND breaking `mdns_lite`. Both the crash
and the restart issue were fixed. The `mdns_lite` side effect was due to its
multicast group membership being lost so this would affect other multicast-using
code.

* Fixed
  * Fix `:timeout_value` crash in the `InternetConnectivityChecker`
  * Force clear IPv4 addresses when the DHCP notifies a deconfig event. This
    occurs on a restart and is quickly followed by a renew. However, if
    applications don't see this, bounce and don't register their multicast
    listeners on affected IPv4 address again, they'll lose the subscription.

* Added
  * Added check for `nerves_network` and `nerves_init_gadget`. If your project
    pulls these in, it will get a moderately friendly notice to remove them.

## [v0.7.0] - 2019-12-09

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

## [v0.6.6] - 2019-12-01

* Fixed
  * Fix warning from Dialyzer when making wild card subscriptions. Code was also
    added to more thoroughly validate properties paths to raise on subtle issues
    that won't do what the programmer intends.

* Added
  * Added `VintageNet.match/1` to support "gets" on properties using wildcards.

## [v0.6.5] - 2019-11-22

* Added
  * Support wild card subscriptions to properties. This makes it possible to
    subscribe to things like `["interface", :_, "addresses"]` where the `:_`
    indicates that any value in the second position should match. That
    particular subscription would send a message whenever an IP address anywhere
    gets added, changed, or removed.

## [v0.6.4] - 2019-10-31

* Added
  * Added the `["interface", ifname, "eap_status"]` property for EAP
    events. EAP is currently only supported on WiFi, but is anticipated for
    wired Ethernet too.

## [v0.6.3] - 2019-10-28

This release renames the WiFi mode names. The old names still work so it's a
backwards compatible update. The new names are `:ap` and `:infrastructure`
instead of `:host` and `:client`. These names match the mode names in the IEEE
specifications and usage elsewhere.

* Added
  * Support static IPv4 configurations for a default gateway and list of name
    resolvers. See `:gateway` and `:name_servers` parameters.
  * Support ad-hoc WiFi networking (IBSS mode)

## [v0.6.2] - 2019-10-11

* Added
  * Support running a simple DNS server on an interface. This was added for WiFi
    AP mode configuration and could be useful for other scenarios.
  * Support DHCP server response options
  * Support disabling configuration persistence on a per-call basis. This is for
    temporary configurations where a reboot should not preserve the setting. For
    example, `VintageNet.configure("wlan0", config, persist: false)`

## [v0.6.1] - 2019-10-02

* Added
  * Add a `current_ap` property for WiFi interfaces so that programs can get
    information about the currently associated access point
  * Support running a DHCP server on wired Ethernet interfaces
  * Expose `VintageNet.WiFi.WPA2.validate_passphrase/1` so that applications can
    reuse the WiFI passphrase validation logic. This logic follows IEEE Std
    802.11i-2004 and validates things like proper length and character set

## [v0.6.0] - 2019-09-25

IMPORTANT: This release contains a LOT of changes. VintageNet is still pre-1.0
and we're actively making API changes as we gain real world experience with it.
Please upgrade carefully.

* Changed
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

* Added
  * USB gadget support - See `VintageNet.Technology.Gadget`. It is highly likely
    that we'll refactor USB gadget support to its own project in the future.
  * Add `:verbose` key to configs for enabling debug messages from third party
    applications. Currently `:verbose` controls debug output from
    `wpa_supplicant`.
  * Allow users to pass additional options to `MuonTrap` so that it's possible
    to run network daemons in cgroups (among other things)

* Fixed
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

## [v0.5.1] - 2019-09-03

* Fixed
  * Add missing PSK conversion when configuring multiple WiFi networks. This
    fixes a bug where backup networks wouldn't connect.

* Added
  * Don't poll WiFi networks that are configured for AP mode for Internet. They
    will never have it.
  * Reduce the number of calls to update routing tables. Previously they were
    unnecessarily updated on DHCP failures due to timeouts. This also removes
    quite a bit of noise from the log.
  * Filter out interfaces with "Null" technologies on them from the configured
    list. They really aren't configured so it was confusing to see them.

## [v0.5.0] - 2019-08-08

Backwards incompatible change: The WiFi access point property (e.g.,
["interfaces", "wlan0", "access_points"]) is now a simple list of access point
structs. It was formerly a map and code using this property will need to be
updated.

## [v0.4.1] - 2019-07-29

* Added
  * Support run-time configuration of regulatory domain
  * Error message improvement if build system is missing pkg-config

## [v0.4.0] - 2019-07-22

Build note: The fix to support AP scanning when in AP-mode (see below) required
pulling in libnl-3. All official Nerves systems have it installed since it is
required by the wpa_supplicant. If you're doing host builds on Linux, you'll
need to run `apt install libnl-genl-3-dev`.

* Added
  * Report IP addresses in the interface properties. It's now possible to listen
    for IP address changes on interfaces. IPv4 and IPv6 addresses are reported.
  * Support scanning for WiFi networks when an WiFi module is in AP mode. This
    lets you make WiFi configuration wizards. See the vintage_net_wizard
    project.
  * Add interface MAC addresses to the interface properties

* Fixed
  * Some WiFi adapters didn't work in AP mode since their drivers didn't support
    the P2P interface. Raspberry Pis all support the P2P interface, but some USB
    WiFi dongles do not. The wpa_supplicant interface code was updated to use
    fallback to the non-P2P interface in AP mode if it wasn't available.

## [v0.3.1] - 2019-06-28

* Added
  * Add null persistence implementation for devices migrating from Nerves
    Network that already have a persistence strategy in place

## [v0.3.0] - 2019-06-27

* Added
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

* Fixed
  * Support scanning WiFi access points with Unicode names (emoji, etc. in their
    SSIDs)
  * Allow internet connectivity pings to be missed 3 times in a row before
    deciding that the internet isn't reachable. This avoids transients due to
    the random dropped packet.
  * Reduce externally visible transients due to internal GenServers crashing and
    restarting - also addressed the crashes
  * Support configure while configuring - let's you cancel a configuration that
    takes a long time to apply and apply a new one

## [v0.2.4] - 2019-06-03

* Added
  * Listen for interface additions and physical layer notifications so that
    routing and status updates can be made much more quickly
  * Add `lower_up` to the interface properties

## [v0.2.3] - 2019-05-29

* Fixed
  * This release fixes supervision issues so that internal VintageNet crashes
    can be recovered
  * `VintageNet.get_configuration/1` works now
  * `"available_interfaces"` is updated again

## [v0.2.2] - 2019-05-24

* Fixed
  * Fix local LAN routing

## [v0.2.1] - 2019-05-16

* Added
  * Expose summary status of whether the whole device is
    disconnected, LAN-connected, or Internet-connected

## [v0.2.0] - 2019-05-15

* Added
  * Support WiFi AP mode - see README.md for example

* Fixed
  * Alway update local routes before default routes to avoid getting errors when
    Linux detects a table entry that cannot be routed

## v0.1.0

Initial release to hex.

[v0.13.4]: https://github.com/nerves-networking/vintage_net/compare/v0.13.3...v0.13.4
[v0.13.3]: https://github.com/nerves-networking/vintage_net/compare/v0.13.2...v0.13.3
[v0.13.2]: https://github.com/nerves-networking/vintage_net/compare/v0.13.1...v0.13.2
[v0.13.1]: https://github.com/nerves-networking/vintage_net/compare/v0.13.0...v0.13.1
[v0.13.0]: https://github.com/nerves-networking/vintage_net/compare/v0.12.2...v0.13.0
[v0.12.2]: https://github.com/nerves-networking/vintage_net/compare/v0.12.1...v0.12.2
[v0.12.1]: https://github.com/nerves-networking/vintage_net/compare/v0.12.0...v0.12.1
[v0.12.0]: https://github.com/nerves-networking/vintage_net/compare/v0.11.5...v0.12.0
[v0.11.5]: https://github.com/nerves-networking/vintage_net/compare/v0.11.4...v0.11.5
[v0.11.4]: https://github.com/nerves-networking/vintage_net/compare/v0.11.3...v0.11.4
[v0.11.3]: https://github.com/nerves-networking/vintage_net/compare/v0.11.2...v0.11.3
[v0.11.2]: https://github.com/nerves-networking/vintage_net/compare/v0.11.1...v0.11.2
[v0.11.1]: https://github.com/nerves-networking/vintage_net/compare/v0.11.0...v0.11.1
[v0.11.0]: https://github.com/nerves-networking/vintage_net/compare/v0.10.5...v0.11.0
[v0.10.5]: https://github.com/nerves-networking/vintage_net/compare/v0.10.4...v0.10.5
[v0.10.4]: https://github.com/nerves-networking/vintage_net/compare/v0.10.3...v0.10.4
[v0.10.3]: https://github.com/nerves-networking/vintage_net/compare/v0.10.2...v0.10.3
[v0.10.2]: https://github.com/nerves-networking/vintage_net/compare/v0.10.1...v0.10.2
[v0.10.1]: https://github.com/nerves-networking/vintage_net/compare/v0.10.0...v0.10.1
[v0.10.0]: https://github.com/nerves-networking/vintage_net/compare/v0.9.3...v0.10.0
[v0.9.3]: https://github.com/nerves-networking/vintage_net/compare/v0.9.2...v0.9.3
[v0.9.2]: https://github.com/nerves-networking/vintage_net/compare/v0.9.1...v0.9.2
[v0.9.1]: https://github.com/nerves-networking/vintage_net/compare/v0.9.0...v0.9.1
[v0.9.0]: https://github.com/nerves-networking/vintage_net/compare/v0.8.0...v0.9.0
[v0.8.0]: https://github.com/nerves-networking/vintage_net/compare/v0.7.9...v0.8.0
[v0.7.9]: https://github.com/nerves-networking/vintage_net/compare/v0.7.8...v0.7.9
[v0.7.8]: https://github.com/nerves-networking/vintage_net/compare/v0.7.7...v0.7.8
[v0.7.7]: https://github.com/nerves-networking/vintage_net/compare/v0.7.6...v0.7.7
[v0.7.6]: https://github.com/nerves-networking/vintage_net/compare/v0.7.5...v0.7.6
[v0.7.5]: https://github.com/nerves-networking/vintage_net/compare/v0.7.4...v0.7.5
[v0.7.4]: https://github.com/nerves-networking/vintage_net/compare/v0.7.3...v0.7.4
[v0.7.3]: https://github.com/nerves-networking/vintage_net/compare/v0.7.2...v0.7.3
[v0.7.2]: https://github.com/nerves-networking/vintage_net/compare/v0.7.1...v0.7.2
[v0.7.1]: https://github.com/nerves-networking/vintage_net/compare/v0.7.0...v0.7.1
[v0.7.0]: https://github.com/nerves-networking/vintage_net/compare/v0.6.6...v0.7.0
[v0.6.6]: https://github.com/nerves-networking/vintage_net/compare/v0.6.5...v0.6.6
[v0.6.5]: https://github.com/nerves-networking/vintage_net/compare/v0.6.4...v0.6.5
[v0.6.4]: https://github.com/nerves-networking/vintage_net/compare/v0.6.3...v0.6.4
[v0.6.3]: https://github.com/nerves-networking/vintage_net/compare/v0.6.2...v0.6.3
[v0.6.2]: https://github.com/nerves-networking/vintage_net/compare/v0.6.1...v0.6.2
[v0.6.1]: https://github.com/nerves-networking/vintage_net/compare/v0.6.0...v0.6.1
[v0.6.0]: https://github.com/nerves-networking/vintage_net/compare/v0.5.1...v0.6.0
[v0.5.1]: https://github.com/nerves-networking/vintage_net/compare/v0.5.0...v0.5.1
[v0.5.0]: https://github.com/nerves-networking/vintage_net/compare/v0.4.1...v0.5.0
[v0.4.1]: https://github.com/nerves-networking/vintage_net/compare/v0.4.0...v0.4.3
[v0.4.0]: https://github.com/nerves-networking/vintage_net/compare/v0.3.1...v0.4.2
[v0.3.1]: https://github.com/nerves-networking/vintage_net/compare/v0.3.0...v0.3.1
[v0.3.0]: https://github.com/nerves-networking/vintage_net/compare/v0.2.4...v0.3.0
[v0.2.4]: https://github.com/nerves-networking/vintage_net/compare/v0.2.3...v0.2.4
[v0.2.3]: https://github.com/nerves-networking/vintage_net/compare/v0.2.2...v0.2.3
[v0.2.2]: https://github.com/nerves-networking/vintage_net/compare/v0.2.1...v0.2.2
[v0.2.1]: https://github.com/nerves-networking/vintage_net/compare/v0.2.0...v0.2.1
[v0.2.0]: https://github.com/nerves-networking/vintage_net/compare/v0.1.0...v0.2.0
