#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

typedef ssize_t (*sendto_fn)(int, const void *, size_t, int, const struct sockaddr *, socklen_t);
typedef ssize_t (*sendmsg_fn)(int, const struct msghdr *, int);
typedef int (*close_fn)(int);

static sendto_fn real_sendto;
static sendmsg_fn real_sendmsg;
static close_fn real_close;
static pthread_once_t resolve_once = PTHREAD_ONCE_INIT;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static unsigned char seen[65536];

static void resolve_functions(void) {
  real_sendto = (sendto_fn)dlsym(RTLD_NEXT, "sendto");
  real_sendmsg = (sendmsg_fn)dlsym(RTLD_NEXT, "sendmsg");
  real_close = (close_fn)dlsym(RTLD_NEXT, "close");
}

static bool enabled(void) {
  const char *value = getenv("DISCORD_DROVER_UDP_BYPASS");
  return value && strcmp(value, "1") == 0;
}

static bool should_inject(int fd, size_t length) {
  if (!enabled() || length != 74 || fd < 0 || fd >= (int)sizeof(seen)) return false;
  int socket_type = 0;
  socklen_t option_length = sizeof(socket_type);
  if (getsockopt(fd, SOL_SOCKET, SO_TYPE, &socket_type, &option_length) != 0 || socket_type != SOCK_DGRAM) return false;
  pthread_mutex_lock(&lock);
  bool inject = !seen[fd];
  seen[fd] = 1;
  pthread_mutex_unlock(&lock);
  return inject;
}

static void send_packet_file(int fd, const struct sockaddr *destination, socklen_t destination_length, int flags) {
  const char *path = getenv("DISCORD_DROVER_PACKET");
  if (!path || !*path) return;
  FILE *file = fopen(path, "rb");
  if (!file) return;
  unsigned char buffer[65536];
  size_t length = fread(buffer, 1, sizeof(buffer), file);
  fclose(file);
  if (length) (void)real_sendto(fd, buffer, length, flags, destination, destination_length);
}

static void inject_before_voice_packet(int fd, const struct sockaddr *destination, socklen_t destination_length, int flags) {
  unsigned char payload;
  send_packet_file(fd, destination, destination_length, flags);
  payload = 0;
  (void)real_sendto(fd, &payload, 1, flags, destination, destination_length);
  payload = 1;
  (void)real_sendto(fd, &payload, 1, flags, destination, destination_length);
}

ssize_t sendto(int fd, const void *buffer, size_t length, int flags,
               const struct sockaddr *destination, socklen_t destination_length) {
  pthread_once(&resolve_once, resolve_functions);
  if (!real_sendto) { errno = ENOSYS; return -1; }
  if (should_inject(fd, length)) inject_before_voice_packet(fd, destination, destination_length, flags);
  return real_sendto(fd, buffer, length, flags, destination, destination_length);
}

ssize_t sendmsg(int fd, const struct msghdr *message, int flags) {
  pthread_once(&resolve_once, resolve_functions);
  if (!real_sendmsg) { errno = ENOSYS; return -1; }
  size_t length = 0;
  if (message)
    for (size_t i = 0; i < message->msg_iovlen; i++) length += message->msg_iov[i].iov_len;
  if (message && should_inject(fd, length))
    inject_before_voice_packet(fd, message->msg_name, message->msg_namelen, flags);
  return real_sendmsg(fd, message, flags);
}

int close(int fd) {
  pthread_once(&resolve_once, resolve_functions);
  if (fd >= 0 && fd < (int)sizeof(seen)) {
    pthread_mutex_lock(&lock);
    seen[fd] = 0;
    pthread_mutex_unlock(&lock);
  }
  if (!real_close) { errno = ENOSYS; return -1; }
  return real_close(fd);
}
