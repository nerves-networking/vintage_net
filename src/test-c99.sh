#!/bin/sh

if [ -z $CC ]; then
  CC=cc
fi

# See Makefile
$CC $CFLAGS -std=c99 -D_XOPEN_SOURCE=600 -o /dev/null -xc - 2>/dev/null <<EOF
// For whatever reason, this test is more robust when the include
// order matches what's in netif.c
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

int main(int argc,char *argv[]) {
    return IFF_UP;
}
EOF
if [ "$?" = "0" ]; then
    printf "yes"
fi

