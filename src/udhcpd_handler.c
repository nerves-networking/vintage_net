#include <ctype.h>
#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include <ei.h>

#define SOCKET_PATH "/tmp/vintage_net/comms"

static void encode_string(ei_x_buff *buff, const char *str)
{
    // Encode strings as binaries so that we get Elixir strings
    // NOTE: the strings that we encounter here are expected to be ASCII to
    //       my knowledge
    ei_x_encode_binary(buff, str, strlen(str));
}

static void encode_kv_string(ei_x_buff *buff, const char *key, const char *str)
{
    ei_x_encode_atom(buff, key);
    encode_string(buff, str);
}

int main(int argc, char *argv[])
{
    // if (argc != 2)
        // errx(EXIT_FAILURE, "Expecting a command from udhcpc");
    int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
    if (fd < 0)
        err(EXIT_FAILURE, "socket");

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) == -1)
        err(EXIT_FAILURE, "connect");

    ei_x_buff buff;
    if (ei_x_new_with_version(&buff) < 0)
        err(EXIT_FAILURE, "ei_x_new_with_version");

    ei_x_encode_tuple_header(&buff, 2);
    ei_x_encode_atom(&buff, "udhcpd");
    ei_x_encode_map_header(&buff, 2);
    ei_x_encode_atom(&buff, "command");
    ei_x_encode_atom(&buff, "lease_update");
    encode_kv_string(&buff, "interface", argv[0]);

    ssize_t rc = write(fd, buff.buff, buff.index);
    if (rc < 0)
        err(EXIT_FAILURE, "write");

    if (rc != buff.index)
        errx(EXIT_FAILURE, "write wasn't able to send %d chars all at once!", buff.index);

    close(fd);
    return 0;
}
