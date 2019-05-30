/*
 *  Copyright 2014-2019 Frank Hunleth
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <err.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <arpa/inet.h>
#include <libmnl/libmnl.h>
#include <net/if_arp.h>
#include <net/if.h>
#include <net/route.h>
#include <linux/if.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>

#include <ei.h>

// In Ubuntu 16.04, it seems that the new compat logic handling is preventing
// IFF_LOWER_UP from being defined properly. It looks like a bug, so define it
// here so that this file compiles.  A scan of all Nerves platforms and Ubuntu
// 16.04 has IFF_LOWER_UP always being set to 0x10000.
#define WORKAROUND_IFF_LOWER_UP (0x10000)

#define MACADDR_STR_LEN      18 // aa:bb:cc:dd:ee:ff and a null terminator

//#define DEBUG
#ifdef DEBUG
#define debug(...) do { fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\r\n"); } while(0)
#else
#define debug(...)
#endif

struct netif {
    // NETLINK_ROUTE socket information
    struct mnl_socket *nl;

    // NETLINK_KOBJECT_UEVENT socket information
    struct mnl_socket *nl_uevent;

    // Netlink buffering
    char nlbuf[8192]; // See MNL_SOCKET_BUFFER_SIZE
};

static void netif_init(struct netif *nb)
{
    memset(nb, 0, sizeof(*nb));
    nb->nl = mnl_socket_open(NETLINK_ROUTE);
    if (!nb->nl)
        err(EXIT_FAILURE, "mnl_socket_open (NETLINK_ROUTE)");

    if (mnl_socket_bind(nb->nl, RTMGRP_LINK, MNL_SOCKET_AUTOPID) < 0)
        err(EXIT_FAILURE, "mnl_socket_bind");

    nb->nl_uevent = mnl_socket_open(NETLINK_KOBJECT_UEVENT);
    if (!nb->nl_uevent)
        err(EXIT_FAILURE, "mnl_socket_open (NETLINK_KOBJECT_UEVENT)");

    // There is one single group in kobject over netlink
    if (mnl_socket_bind(nb->nl_uevent, (1<<0), MNL_SOCKET_AUTOPID) < 0)
        err(EXIT_FAILURE, "mnl_socket_bind");
}

static void netif_cleanup(struct netif *nb)
{
    mnl_socket_close(nb->nl);
    mnl_socket_close(nb->nl_uevent);
    nb->nl = NULL;
    nb->nl_uevent = NULL;
}

static int collect_if_attrs(const struct nlattr *attr, void *data)
{
    const struct nlattr **tb = data;
    int type = mnl_attr_get_type(attr);

    // Skip unsupported attributes in user-space
    if (mnl_attr_type_valid(attr, IFLA_MAX) < 0)
        return MNL_CB_OK;

    // Only save supported attributes (see encode logic)
    switch (type) {
    case IFLA_MTU:
    case IFLA_IFNAME:
    case IFLA_ADDRESS:
    case IFLA_BROADCAST:
    case IFLA_LINK:
    case IFLA_OPERSTATE:
    case IFLA_STATS:
        tb[type] = attr;
        break;

    default:
        break;
    }
    return MNL_CB_OK;
}

static int macaddr_to_string(const unsigned char *mac, char *str)
{
    snprintf(str, MACADDR_STR_LEN,
             "%02x:%02x:%02x:%02x:%02x:%02x",
             mac[0], mac[1], mac[2],
             mac[3], mac[4], mac[5]);
    return 0;
}

static void encode_kv_ulong(ei_x_buff *buff, const char *key, unsigned long value)
{
    ei_x_encode_atom(buff, key);
    ei_x_encode_ulong(buff, value);
}
static void encode_kv_bool(ei_x_buff *buff, const char *key, int value)
{
    ei_x_encode_atom(buff, key);
    ei_x_encode_boolean(buff, value);
}
static void encode_string(ei_x_buff *buff, const char *str)
{
    // Encode strings as binaries so that we get Elixir strings
    // NOTE: the strings that we encounter here are expected to be ASCII to
    //       my knowledge
    ei_x_encode_binary(buff, str, strlen(str));
}

static void encode_kv_macaddr(ei_x_buff *buff, const char *key, const unsigned char *macaddr)
{
    ei_x_encode_atom(buff, key);

    char macaddr_str[MACADDR_STR_LEN];

    // Only handle 6 byte mac addresses (to my knowledge, this is the only case)
    macaddr_to_string(macaddr, macaddr_str);

    encode_string(buff, macaddr_str);
}

static void encode_kv_stats(ei_x_buff *buff, const char *key, struct nlattr *attr)
{
    struct rtnl_link_stats *stats = (struct rtnl_link_stats *) mnl_attr_get_payload(attr);

    ei_x_encode_atom(buff, key);
    ei_x_encode_map_header(buff, 10);
    encode_kv_ulong(buff, "rx_packets", stats->rx_packets);
    encode_kv_ulong(buff, "tx_packets", stats->tx_packets);
    encode_kv_ulong(buff, "rx_bytes", stats->rx_bytes);
    encode_kv_ulong(buff, "tx_bytes", stats->tx_bytes);
    encode_kv_ulong(buff, "rx_errors", stats->rx_errors);
    encode_kv_ulong(buff, "tx_errors", stats->tx_errors);
    encode_kv_ulong(buff, "rx_dropped", stats->rx_dropped);
    encode_kv_ulong(buff, "tx_dropped", stats->tx_dropped);
    encode_kv_ulong(buff, "multicast", stats->multicast);
    encode_kv_ulong(buff, "collisions", stats->collisions);
}

static void encode_kv_operstate(ei_x_buff *buff, int operstate)
{
    ei_x_encode_atom(buff, "operstate");

    // Refer to RFC2863 for state descriptions (or the kernel docs)
    const char *operstate_atom;
    switch (operstate) {
    default:
    case IF_OPER_UNKNOWN:
        operstate_atom = "unknown";
        break;
    case IF_OPER_NOTPRESENT:
        operstate_atom = "notpresent";
        break;
    case IF_OPER_DOWN:
        operstate_atom = "down";
        break;
    case IF_OPER_LOWERLAYERDOWN:
        operstate_atom = "lowerlayerdown";
        break;
    case IF_OPER_TESTING:
        operstate_atom = "testing";
        break;
    case IF_OPER_DORMANT:
        operstate_atom = "dormant";
        break;
    case IF_OPER_UP:
        operstate_atom = "up";
        break;
    }
    ei_x_encode_atom(buff, operstate_atom);
}

static int netif_build_ifinfo(const struct nlmsghdr *nlh, void *data)
{
    ei_x_buff *buff = (ei_x_buff *) data;
    struct nlattr *tb[IFLA_MAX + 1];
    memset(tb, 0, sizeof(tb));
    struct ifinfomsg *ifm = mnl_nlmsg_get_payload(nlh);

    if (mnl_attr_parse(nlh, sizeof(*ifm), collect_if_attrs, tb) != MNL_CB_OK) {
        debug("Error from mnl_attr_parse");
        return MNL_CB_ERROR;
    }

    ei_x_encode_tuple_header(buff, 4);
    ei_x_encode_atom(buff, "report");

    if (tb[IFLA_IFNAME])
        encode_string(buff, mnl_attr_get_str(tb[IFLA_IFNAME]));
    else
        return MNL_CB_ERROR;

    ei_x_encode_long(buff, ifm->ifi_index);

    int count = 5; // Base number of fields. Mandatory fields - name
    int i;
    for (i = 0; i <= IFLA_MAX; i++)
        if (tb[i])
            count++;

    ei_x_encode_map_header(buff, count);

    ei_x_encode_atom(buff, "type");
    ei_x_encode_atom(buff, ifm->ifi_type == ARPHRD_ETHER ? "ethernet" : "other");

    encode_kv_bool(buff, "up", ifm->ifi_flags & IFF_UP);
    encode_kv_bool(buff, "broadcast", ifm->ifi_flags & IFF_BROADCAST);
    encode_kv_bool(buff, "running", ifm->ifi_flags & IFF_RUNNING);
    encode_kv_bool(buff, "lower_up", ifm->ifi_flags & WORKAROUND_IFF_LOWER_UP);
    encode_kv_bool(buff, "multicast", ifm->ifi_flags & IFF_MULTICAST);

    if (tb[IFLA_MTU])
        encode_kv_ulong(buff, "mtu", mnl_attr_get_u32(tb[IFLA_MTU]));
    if (tb[IFLA_ADDRESS])
        encode_kv_macaddr(buff, "mac_address", mnl_attr_get_payload(tb[IFLA_ADDRESS]));
    if (tb[IFLA_BROADCAST])
        encode_kv_macaddr(buff, "mac_broadcast", mnl_attr_get_payload(tb[IFLA_BROADCAST]));
    if (tb[IFLA_LINK])
        encode_kv_ulong(buff, "link", mnl_attr_get_u32(tb[IFLA_LINK]));
    if (tb[IFLA_OPERSTATE])
        encode_kv_operstate(buff, mnl_attr_get_u32(tb[IFLA_OPERSTATE]));
    if (tb[IFLA_STATS])
        encode_kv_stats(buff, "stats", tb[IFLA_STATS]);

    return MNL_CB_OK;
}

static void write_buff(const ei_x_buff *buff)
{
    uint16_t be_len = htons(buff->index);
    ssize_t rc = write(STDOUT_FILENO, &be_len, sizeof(be_len));
    if (rc < 0 || rc != sizeof(be_len))
        err(EXIT_FAILURE, "write length");

    rc = write(STDOUT_FILENO, buff->buff, buff->index);
    if (rc < 0)
        err(EXIT_FAILURE, "write");

    if (rc != buff->index)
        errx(EXIT_FAILURE, "write wasn't able to send %d chars all at once!", buff->index);
}

static void netif_request_status(struct netif *nb,
                                 int index)
{
    static int seq = 1;
    struct nlmsghdr *nlh;
    struct ifinfomsg *ifi;

    nlh = mnl_nlmsg_put_header(nb->nlbuf);
    nlh->nlmsg_type = RTM_GETLINK;
    nlh->nlmsg_flags = NLM_F_REQUEST;
    nlh->nlmsg_seq = seq++;

    ifi = mnl_nlmsg_put_extra_header(nlh, sizeof(struct ifinfomsg));
    ifi->ifi_family = AF_UNSPEC;
    ifi->ifi_type = ARPHRD_ETHER;
    ifi->ifi_index = index;
    ifi->ifi_flags = 0;
    ifi->ifi_change = 0xffffffff;

    if (mnl_socket_sendto(nb->nl, nlh, nlh->nlmsg_len) < 0)
        err(EXIT_FAILURE, "mnl_socket_send");
}


static void nl_uevent_process(struct netif *nb)
{
    int bytecount = mnl_socket_recvfrom(nb->nl_uevent, nb->nlbuf, sizeof(nb->nlbuf));
    if (bytecount <= 0)
        err(EXIT_FAILURE, "mnl_socket_recvfrom");

    // uevent messages are concatenated strings
    enum hotplug_operation {
        HOTPLUG_OPERATION_NONE = 0,
        HOTPLUG_OPERATION_ADD,
        HOTPLUG_OPERATION_MOVE,
        HOTPLUG_OPERATION_REMOVE
    } operation;

    const char *str = nb->nlbuf;
    if (strncmp(str, "add@", 4) == 0)
        operation = HOTPLUG_OPERATION_ADD;
    else if (strncmp(str, "move@", 5) == 0)
        operation = HOTPLUG_OPERATION_MOVE;
    else if (strncmp(str, "remove@", 7) == 0)
        operation = HOTPLUG_OPERATION_REMOVE;
    else
        return; // Not interested in this message.

    const char *str_end = str + bytecount;
    str += strlen(str) + 1;

    // Extract the fields of interest
    const char *ifname = NULL;
    const char *subsystem = NULL;
    const char *ifindex_str = NULL;
    for (; str < str_end; str += strlen(str) + 1) {
        if (strncmp(str, "INTERFACE=", 10) == 0)
            ifname = str + 10;
        else if (strncmp(str, "SUBSYSTEM=", 10) == 0)
            subsystem = str + 10;
        else if (strncmp(str, "IFINDEX=", 8) == 0)
            ifindex_str = str + 8;
    }

    // Check that we have the required fields that this is a
    // "net" subsystem event. If yes, send the notification.
    if (ifname && subsystem && ifindex_str && strcmp(subsystem, "net") == 0) {
        ei_x_buff buff;
        if (ei_x_new_with_version(&buff) < 0)
            err(EXIT_FAILURE, "ei_x_new_with_version");

        ei_x_encode_tuple_header(&buff, 3);

        switch (operation) {
        case HOTPLUG_OPERATION_ADD:
            ei_x_encode_atom(&buff, "added");
            break;
        case HOTPLUG_OPERATION_MOVE:
            ei_x_encode_atom(&buff, "renamed");
            break;
        case HOTPLUG_OPERATION_REMOVE:
        default: // Silence warning
            ei_x_encode_atom(&buff, "removed");
            break;
        }

        encode_string(&buff, ifname);

        int ifindex = strtol(ifindex_str, NULL, 0);
        ei_x_encode_long(&buff, ifindex);

        write_buff(&buff);

        // Force a refresh on the interface status if it was added or moved
        if (operation == HOTPLUG_OPERATION_ADD || operation == HOTPLUG_OPERATION_MOVE)
            netif_request_status(nb, ifindex);
    }
}

static void handle_notification(struct netif *nb, int bytecount)
{
    ei_x_buff buff;

    if (ei_x_new_with_version(&buff) < 0)
        err(EXIT_FAILURE, "ei_x_new_with_version");

    if (mnl_cb_run(nb->nlbuf, bytecount, 0, 0, netif_build_ifinfo, &buff) <= 0)
        err(EXIT_FAILURE, "mnl_cb_run");

    write_buff(&buff);
}

static void nl_route_process(struct netif *nb)
{
    int bytecount = mnl_socket_recvfrom(nb->nl, nb->nlbuf, sizeof(nb->nlbuf));
    if (bytecount <= 0)
        err(EXIT_FAILURE, "mnl_socket_recvfrom");

    handle_notification(nb, bytecount);
}

static void request_all_interfaces(struct netif *nb)
{
    struct if_nameindex *if_ni = if_nameindex();
    if (if_ni == NULL)
        err(EXIT_FAILURE, "if_nameindex");

    for (struct if_nameindex *i = if_ni;
            ! (i->if_index == 0 && i->if_name == NULL);
            i++) {
        netif_request_status(nb, i->if_index);
    }

    if_freenameindex(if_ni);
}

int main(int argc, char *argv[])
{
    (void) argc;
    (void) argv;

    struct netif nb;
    netif_init(&nb);

    /* Seed Elixir with notifications from all of the current interfaces */
    request_all_interfaces(&nb);

    for (;;) {
        struct pollfd fdset[3];

        fdset[0].fd = STDIN_FILENO;
        fdset[0].events = POLLIN;
        fdset[0].revents = 0;

        fdset[1].fd = mnl_socket_get_fd(nb.nl);
        fdset[1].events = POLLIN;
        fdset[1].revents = 0;

        fdset[2].fd = mnl_socket_get_fd(nb.nl_uevent);
        fdset[2].events = POLLIN;
        fdset[2].revents = 0;

        int rc = poll(fdset, 3, -1);
        if (rc < 0) {
            // Retry if EINTR
            if (errno == EINTR)
                continue;

            err(EXIT_FAILURE, "poll");
        }

        if (fdset[0].revents & (POLLIN | POLLHUP))
            break;
        if (fdset[1].revents & (POLLIN | POLLHUP))
            nl_route_process(&nb);
        if (fdset[2].revents & (POLLIN | POLLHUP))
            nl_uevent_process(&nb);
    }

    netif_cleanup(&nb);
    return 0;
}
