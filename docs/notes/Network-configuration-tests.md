There's an investigation going on for whether an Elixir library that generates `/etc/network/interface` and `wpa_supplicant.conf` files and does the equivalent of running `ifup` and `ifdown` can replace the current `nerves_network`. Scanning WiFi networks and getting real-time stats is assumed to be provided separately by new or trimmed down versions of `nerves_network_interface` and `nerves_wpa_supplicant`. Some way of sending messages to Elixir applications is still needed for when interfaces come up or go down. It's TBD how this works, but there are a few options.

The immediate need is to enumerate and test every setup that we'd like to support to check for holes and make sure that we have the necessary programs included in our images to support this.

We're using the following Buildroot config fragment for the networking options:
```patch
+BR2_PACKAGE_WIRELESS_REGDB=y
+BR2_PACKAGE_WPA_SUPPLICANT=y
+BR2_PACKAGE_WPA_SUPPLICANT_AP_SUPPORT=y
+BR2_PACKAGE_WPA_SUPPLICANT_AUTOSCAN=y
+BR2_PACKAGE_WPA_SUPPLICANT_EAP=y
+BR2_PACKAGE_WPA_SUPPLICANT_HOTSPOT=y
+BR2_PACKAGE_WPA_SUPPLICANT_WPS=y
+BR2_PACKAGE_WPA_SUPPLICANT_CLI=y
+BR2_PACKAGE_WPA_SUPPLICANT_WPA_CLIENT_SO=y
+BR2_PACKAGE_WPA_SUPPLICANT_PASSPHRASE=y
```

We're using the following busybox config fragment:
```patch
+CONFIG_RUN_PARTS=y
+CONFIG_FEATURE_RUN_PARTS_LONG_OPTIONS=y
+CONFIG_FEATURE_RUN_PARTS_FANCY=y
+CONFIG_LN=y
+CONFIG_TOUCH=y
+CONFIG_ROUTE=y
+CONFIG_MKTEMP=y
```
Hopefully, all we _should_ need is `CONFIG_ROUTE=y` in the long run.

Here are the setups. Please add missing ones.

* [Static Wired Ethernet](Static-Wired-Ethernet)
* [DHCP Wired Ethernet](DHCP-Wired-Ethernet)
* [Link-local Wired Ethernet](Link-local-Wired-Ethernet)
* [Two DHCP Wired Ethernets](Two-DHCP-Wired-Ethernets)
* [DHCP WiFi WPA2](DHCP-WiFi-WPA2)
* [DHCP WiFi WPA2 Hidden](DHCP-WiFi-WPA2-Hidden)
* [Two DHCP WiFi WPA2](Two-DHCP-WiFi-WPA2)
* [DHCP WiFi None](DHCP-WiFi-None)
* [DHCP WiFi WEP](DHCP-WiFi-WEP)
* [DHCP WiFi WPA-EAP](DHCP-WiFi-WPA-EAP)
* [DHCP WiFi WPA2 AP](DHCP-WiFi-WPA2-AP)
* [DHCP-server USB](DHCP-server-USB)
* [Static Wired Ethernet IPv6](Static-Wired-Ethernet-IPv6)
* [PPP LTE Modem](PPP-LTE-Modem)
* [DHCP-server WPA2 host](Static-WiFi-Host-mode)
* [Wired-802.1X-PEAP-MSCHAPv2](Wired-802.1X-PEAP-MSCHAPv2)

