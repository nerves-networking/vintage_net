#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define SOCKET_PATH "/tmp/vintage_net/comms"

int main(int argc, char *argv[])
{
  struct sockaddr_un addr;
  int fd;

    if ( (fd = socket(AF_UNIX, SOCK_DGRAM, 0)) < 0)
          err(EXIT_FAILURE, "socket");

  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path)-1);

  if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) == -1)
      err(EXIT_FAILURE, "connect");

  write(fd, "hello", 5);

  return 0;
}
