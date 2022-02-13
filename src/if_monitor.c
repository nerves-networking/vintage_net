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

#define MACADDR_STR_LEN 18 // aa:bb:cc:dd:ee:ff and a null terminator

//#define DEBUG
#ifdef DEBUG
#define debug(...)                    \
    do                                \
    {                                 \
        fprintf(stderr, __VA_ARGS__); \
        fprintf(stderr, "\r\n");      \
    } while (0)
#else
#define debug(...)
#endif

struct netif
{
    // NETLINK_ROUTE socket for link information
    struct mnl_socket *nl_link;

    // NETLINK_ROUTE socket for address information
    // NOTE: nl_addr and nl_link could share a socket, but
    //       then you have to sequencing the initial dump
    //       link and address operations.
    struct mnl_socket *nl_addr;

    // Sequence numbers for requests
    int seq;

    // Netlink buffering
    char nlbuf[8192]; // See MNL_SOCKET_BUFFER_SIZE
};

static void netif_init(struct netif *nb)
{
    memset(nb, 0, sizeof(*nb));
    nb->seq = 10;
    nb->nl_link = mnl_socket_open(NETLINK_ROUTE);
    if (!nb->nl_link)
        err(EXIT_FAILURE, "mnl_socket_open (NETLINK_ROUTE)");

    if (mnl_socket_bind(nb->nl_link, RTMGRP_LINK, MNL_SOCKET_AUTOPID) < 0)
        err(EXIT_FAILURE, "mnl_socket_bind(RTMGRP_LINK)");

    nb->nl_addr = mnl_socket_open(NETLINK_ROUTE);
    if (!nb->nl_addr)
        err(EXIT_FAILURE, "mnl_socket_open (NETLINK_ROUTE)");

    if (mnl_socket_bind(nb->nl_addr, RTMGRP_IPV4_IFADDR | RTMGRP_IPV6_IFADDR, MNL_SOCKET_AUTOPID) < 0)
        err(EXIT_FAILURE, "mnl_socket_bind(RTMGRP_IPV4_IFADDR)");
}

static void netif_cleanup(struct netif *nb)
{
    mnl_socket_close(nb->nl_link);
    mnl_socket_close(nb->nl_addr);
    nb->nl_link = NULL;
    nb->nl_addr = NULL;
}

static int collect_ifla_attrs(const struct nlattr *attr, void *data)
{
    const struct nlattr **tb = data;
    int type = mnl_attr_get_type(attr);

    // Skip unsupported attributes in user-space
    if (mnl_attr_type_valid(attr, IFLA_MAX) < 0)
        return MNL_CB_OK;

    // Only save supported attributes (see encode logic)
    switch (type)
    {
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

static int collect_ifa_attrs(const struct nlattr *attr, void *data)
{
    const struct nlattr **tb = data;
    int type = mnl_attr_get_type(attr);

    // Skip unsupported attributes in user-space
    if (mnl_attr_type_valid(attr, IFA_MAX) < 0)
        return MNL_CB_OK;

    // Only save supported attributes (see encode logic)
    switch (type)
    {
    case IFA_ADDRESS:
    case IFA_LOCAL:
    case IFA_LABEL:
    case IFA_BROADCAST:
    case IFA_ANYCAST:
    case IFA_MULTICAST:
    case IFA_FLAGS:
        tb[type] = attr;
        break;

    case IFA_CACHEINFO: // not supported
    case IFA_UNSPEC:    // not supported
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

static void encode_kv_raw_address(ei_x_buff *buff, const char *key, const uint8_t *addr, uint16_t len)
{
    ei_x_encode_atom(buff, key);

    switch (len)
    {
    case 16: // IPv6
        ei_x_encode_tuple_header(buff, 8);
        {
            const uint16_t *addr2 = (const uint16_t *)addr;
            uint16_t i;
            for (i = 0; i < 8; i++)
                ei_x_encode_ulong(buff, htons(addr2[i]));
        }
        break;
    default:
        ei_x_encode_tuple_header(buff, len);
        {
            uint16_t i;
            for (i = 0; i < len; i++)
                ei_x_encode_ulong(buff, addr[i]);
        }
        break;
    }
}

static void encode_kv_string(ei_x_buff *buff, const char *key, const char *value)
{
    ei_x_encode_atom(buff, key);
    encode_string(buff, value);
}

static void encode_kv_scope(ei_x_buff *buff, const char *key, uint8_t scope)
{
    ei_x_encode_atom(buff, key);

    switch (scope)
    {
    case RT_SCOPE_UNIVERSE:
        ei_x_encode_atom(buff, "universe");
        break;
    case RT_SCOPE_SITE:
        ei_x_encode_atom(buff, "site");
        break;
    case RT_SCOPE_LINK:
        ei_x_encode_atom(buff, "link");
        break;
    case RT_SCOPE_HOST:
        ei_x_encode_atom(buff, "host");
        break;
    case RT_SCOPE_NOWHERE:
        ei_x_encode_atom(buff, "nowhere");
        break;
    default:
        ei_x_encode_ulong(buff, scope);
        break;
    }
}

static void encode_kv_family(ei_x_buff *buff, const char *key, uint8_t family)
{
    ei_x_encode_atom(buff, key);

    char *str;
    switch (family)
    {
    case AF_UNSPEC:
        str = "unspec";
        break;
    case AF_UNIX:
        str = "unix";
        break;
    case AF_INET:
        str = "inet";
        break;
    case AF_AX25:
        str = "ax25";
        break;
    case AF_IPX:
        str = "ipx";
        break;
    case AF_APPLETALK:
        str = "appletalk";
        break;
    case AF_NETROM:
        str = "netrom";
        break;
    case AF_BRIDGE:
        str = "bridge";
        break;
    case AF_ATMPVC:
        str = "atmpvc";
        break;
    case AF_X25:
        str = "x25";
        break;
    case AF_INET6:
        str = "inet6";
        break;
    case AF_ROSE:
        str = "rose";
        break;
    case AF_DECnet:
        str = "decnet";
        break;
    case AF_NETBEUI:
        str = "netbeui";
        break;
    case AF_SECURITY:
        str = "security";
        break;
    case AF_KEY:
        str = "key";
        break;
    case AF_NETLINK:
        str = "netlink";
        break;
    case AF_PACKET:
        str = "packet";
        break;
    case AF_ASH:
        str = "ash";
        break;
    case AF_ECONET:
        str = "econet";
        break;
    case AF_ATMSVC:
        str = "atmsvc";
        break;
    case AF_RDS:
        str = "rds";
        break;
    case AF_SNA:
        str = "sna";
        break;
    case AF_IRDA:
        str = "irda";
        break;
    case AF_PPPOX:
        str = "pppox";
        break;
    case AF_WANPIPE:
        str = "wanpipe";
        break;
    case AF_LLC:
        str = "llc";
        break;
    case AF_IB:
        str = "ib";
        break;
    case AF_MPLS:
        str = "mpls";
        break;
    case AF_CAN:
        str = "can";
        break;
    case AF_TIPC:
        str = "tipc";
        break;
    case AF_BLUETOOTH:
        str = "bluetooth";
        break;
    case AF_IUCV:
        str = "iucv";
        break;
    case AF_RXRPC:
        str = "rxrpc";
        break;
    case AF_ISDN:
        str = "isdn";
        break;
    case AF_PHONET:
        str = "phonet";
        break;
    case AF_IEEE802154:
        str = "iee802154";
        break;
    case AF_CAIF:
        str = "caif";
        break;
    case AF_ALG:
        str = "alg";
        break;
    case AF_NFC:
        str = "nfc";
        break;
    case AF_VSOCK:
        str = "vsock";
        break;
    case AF_KCM:
        str = "kcm";
        break;
#ifdef AF_QIPCRTR
    case AF_QIPCRTR:
        str = "qipcrtr";
        break;
#endif
#ifdef AF_SMC
    case AF_SMC:
        str = "smc";
        break;
#endif
    default:
        str = "unknown";
        break;
    }

    ei_x_encode_atom(buff, str);
}
static void encode_kv_stats(ei_x_buff *buff, const char *key, struct nlattr *attr)
{
    struct rtnl_link_stats *stats = (struct rtnl_link_stats *)mnl_attr_get_payload(attr);

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
    switch (operstate)
    {
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

static int netif_build_link(ei_x_buff *buff, const char *report, const struct nlmsghdr *nlh)
{
    struct nlattr *tb[IFLA_MAX + 1];
    memset(tb, 0, sizeof(tb));
    struct ifinfomsg *ifm = mnl_nlmsg_get_payload(nlh);

    if (mnl_attr_parse(nlh, sizeof(*ifm), collect_ifla_attrs, tb) != MNL_CB_OK)
    {
        debug("Error from mnl_attr_parse");
        return MNL_CB_ERROR;
    }

    ei_x_encode_tuple_header(buff, 4);
    ei_x_encode_atom(buff, report);

    if (!tb[IFLA_IFNAME])
    {
        debug("IFLA_IFNAME missing and it shouldn't be");
        return MNL_CB_ERROR;
    }
    encode_string(buff, mnl_attr_get_str(tb[IFLA_IFNAME]));

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

static int netif_build_addr(ei_x_buff *buff, const char *report, const struct nlmsghdr *nlh)
{
    struct nlattr *tb[IFA_MAX + 1];
    memset(tb, 0, sizeof(tb));
    struct ifaddrmsg *ifa = mnl_nlmsg_get_payload(nlh);

    if (mnl_attr_parse(nlh, sizeof(*ifa), collect_ifa_attrs, tb) != MNL_CB_OK)
    {
        debug("Error from mnl_attr_parse");
        return MNL_CB_ERROR;
    }

    ei_x_encode_tuple_header(buff, 3);
    ei_x_encode_atom(buff, report);

    ei_x_encode_long(buff, ifa->ifa_index);

    int count = 4; // Base number of fields
    int i;
    for (i = 0; i <= IFA_MAX; i++)
        if (tb[i])
            count++;

    uint32_t flags;
    if (tb[IFA_FLAGS])
    {
        flags = mnl_attr_get_u32(tb[IFA_FLAGS]);
        count--;
    }
    else
    {
        flags = ifa->ifa_flags;
    }

    ei_x_encode_map_header(buff, count);

    encode_kv_family(buff, "family", ifa->ifa_family);
    encode_kv_ulong(buff, "prefixlen", ifa->ifa_prefixlen);
    encode_kv_bool(buff, "permanent", flags & IFA_F_PERMANENT);
    encode_kv_scope(buff, "scope", ifa->ifa_scope);

    if (tb[IFA_ADDRESS])
        encode_kv_raw_address(buff, "address", mnl_attr_get_payload(tb[IFA_ADDRESS]), mnl_attr_get_payload_len(tb[IFA_ADDRESS]));
    if (tb[IFA_LOCAL])
        encode_kv_raw_address(buff, "local", mnl_attr_get_payload(tb[IFA_LOCAL]), mnl_attr_get_payload_len(tb[IFA_LOCAL]));
    if (tb[IFA_LABEL])
        encode_kv_string(buff, "label", mnl_attr_get_payload(tb[IFA_LABEL]));
    if (tb[IFA_BROADCAST])
        encode_kv_raw_address(buff, "broadcast", mnl_attr_get_payload(tb[IFA_BROADCAST]), mnl_attr_get_payload_len(tb[IFA_BROADCAST]));
    if (tb[IFA_ANYCAST])
        encode_kv_raw_address(buff, "anycast", mnl_attr_get_payload(tb[IFA_ANYCAST]), mnl_attr_get_payload_len(tb[IFA_ANYCAST]));
    if (tb[IFA_MULTICAST])
        encode_kv_raw_address(buff, "multicast", mnl_attr_get_payload(tb[IFA_MULTICAST]), mnl_attr_get_payload_len(tb[IFA_MULTICAST]));
    //    if (tb[IFA_CACHEINFO])
    //        encode_kv_cacheinfo(buff, "cacheinfo", mnl_attr_get_payload(tb[IFA_CACHEINFO]));

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

static int netif_build_notification(const struct nlmsghdr *nlh, void *data)
{
    (void)data;

    ei_x_buff buff;
    if (ei_x_new_with_version(&buff) < 0)
        err(EXIT_FAILURE, "ei_x_new_with_version");

    int rc;
    switch (nlh->nlmsg_type)
    {
    case RTM_NEWLINK:
        rc = netif_build_link(&buff, "newlink", nlh);
        break;
    case RTM_DELLINK:
        rc = netif_build_link(&buff, "dellink", nlh);
        break;
    case RTM_NEWADDR:
        rc = netif_build_addr(&buff, "newaddr", nlh);
        break;
    case RTM_DELADDR:
        rc = netif_build_addr(&buff, "deladdr", nlh);
        break;
    default:
        warn("Ignoring netlink message type: %d", nlh->nlmsg_type);
        rc = MNL_CB_ERROR;
        break;
    }

    if (rc == MNL_CB_OK)
        write_buff(&buff);

    return rc;
}

static void handle_notification(struct netif *nb, int bytecount)
{
    if (mnl_cb_run(nb->nlbuf, bytecount, 0, 0, netif_build_notification, NULL) == MNL_CB_ERROR)
        err(EXIT_FAILURE, "mnl_cb_run");
}

static void nl_link_process(struct netif *nb)
{
    int bytecount = mnl_socket_recvfrom(nb->nl_link, nb->nlbuf, sizeof(nb->nlbuf));
    if (bytecount <= 0)
        err(EXIT_FAILURE, "mnl_socket_recvfrom(nl_link)");

    handle_notification(nb, bytecount);
}

static void nl_addr_process(struct netif *nb)
{
    int bytecount = mnl_socket_recvfrom(nb->nl_addr, nb->nlbuf, sizeof(nb->nlbuf));
    if (bytecount <= 0)
        err(EXIT_FAILURE, "mnl_socket_recvfrom(nl_addr)");

    handle_notification(nb, bytecount);
}

static void request_all_interfaces(struct netif *nb)
{
    struct nlmsghdr *nlh;

    // Request all links
    nlh = mnl_nlmsg_put_header(nb->nlbuf);
    nlh->nlmsg_type = RTM_GETLINK;
    nlh->nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
    nlh->nlmsg_seq = nb->seq++;

    struct ifinfomsg *ifi;
    ifi = mnl_nlmsg_put_extra_header(nlh, sizeof(struct ifinfomsg));
    ifi->ifi_family = AF_PACKET;
    ifi->ifi_type = ARPHRD_ETHER;
    ifi->ifi_index = 0;
    ifi->ifi_flags = 0;
    ifi->ifi_change = 0;

    if (mnl_socket_sendto(nb->nl_link, nlh, nlh->nlmsg_len) < 0)
        err(EXIT_FAILURE, "mnl_socket_send(RTM_GETLINK)");

    // Request all addresses
    nlh = mnl_nlmsg_put_header(nb->nlbuf);
    nlh->nlmsg_type = RTM_GETADDR;
    nlh->nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
    nlh->nlmsg_seq = nb->seq++;

    struct ifaddrmsg *ifa;
    ifa = mnl_nlmsg_put_extra_header(nlh, sizeof(struct ifaddrmsg));
    ifa->ifa_family = AF_UNSPEC;
    ifa->ifa_prefixlen = 0;
    ifa->ifa_flags = 0;
    ifa->ifa_scope = RT_SCOPE_UNIVERSE;
    ifa->ifa_index = 0;

    if (mnl_socket_sendto(nb->nl_addr, nlh, nlh->nlmsg_len) < 0)
        err(EXIT_FAILURE, "mnl_socket_send(RTM_GETADDR)");
}

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    struct netif nb;
    netif_init(&nb);

    /* Seed Elixir with notifications from all of the current interfaces */
    request_all_interfaces(&nb);

    for (;;)
    {
        struct pollfd fdset[4];

        fdset[0].fd = mnl_socket_get_fd(nb.nl_link);
        fdset[0].events = POLLIN;
        fdset[0].revents = 0;

        fdset[1].fd = mnl_socket_get_fd(nb.nl_addr);
        fdset[1].events = POLLIN;
        fdset[1].revents = 0;

        fdset[2].fd = STDIN_FILENO;
        fdset[2].events = POLLIN;
        fdset[2].revents = 0;

        int rc = poll(fdset, 3, -1);
        if (rc < 0)
        {
            // Retry if EINTR
            if (errno == EINTR)
                continue;

            err(EXIT_FAILURE, "poll");
        }

        if (fdset[0].revents & (POLLIN | POLLHUP))
            nl_link_process(&nb);
        if (fdset[1].revents & (POLLIN | POLLHUP))
            nl_addr_process(&nb);
        if (fdset[2].revents & (POLLIN | POLLHUP))
            break;
    }

    netif_cleanup(&nb);
    return 0;
}
