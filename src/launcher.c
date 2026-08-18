#define _POSIX_C_SOURCE 200809L

#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <unistd.h>

struct config {
  char proxy[1024];
  char packet_file[PATH_MAX];
  int udp_bypass;
};

static void die(const char *message) {
  fprintf(stderr, "discord-drover: %s\n", message);
  exit(EXIT_FAILURE);
}

static char *trim(char *text) {
  while (isspace((unsigned char)*text)) text++;
  char *end = text + strlen(text);
  while (end > text && isspace((unsigned char)end[-1])) *--end = '\0';
  return text;
}

static void config_path(char *out, size_t out_size) {
  const char *override = getenv("DISCORD_DROVER_CONFIG");
  if (override && *override) {
    snprintf(out, out_size, "%s", override);
    return;
  }
  const char *xdg = getenv("XDG_CONFIG_HOME");
  if (xdg && *xdg)
    snprintf(out, out_size, "%s/discord-drover/drover.ini", xdg);
  else {
    const char *home = getenv("HOME");
    if (!home || !*home) die("HOME is not set; set DISCORD_DROVER_CONFIG instead");
    snprintf(out, out_size, "%s/.config/discord-drover/drover.ini", home);
  }
}

static void parent_dir(const char *path, char *out, size_t out_size) {
  if (out != path) snprintf(out, out_size, "%s", path);
  char *slash = strrchr(out, '/');
  if (slash) *slash = '\0';
  else snprintf(out, out_size, ".");
}

static void load_config(struct config *cfg, const char *path) {
  memset(cfg, 0, sizeof(*cfg));
  cfg->udp_bypass = 1;
  FILE *file = fopen(path, "r");
  if (!file) {
    if (errno == ENOENT) return;
    perror(path);
    exit(EXIT_FAILURE);
  }
  char line[2048];
  while (fgets(line, sizeof(line), file)) {
    char *key = trim(line);
    if (*key == '#' || *key == ';' || *key == '[' || *key == '\0') continue;
    char *equals = strchr(key, '=');
    if (!equals) continue;
    *equals = '\0';
    char *value = trim(equals + 1);
    key = trim(key);
    if (!strcasecmp(key, "proxy")) snprintf(cfg->proxy, sizeof(cfg->proxy), "%s", value);
    else if (!strcasecmp(key, "udp_bypass"))
      cfg->udp_bypass = !(!strcasecmp(value, "false") || !strcasecmp(value, "no") || !strcmp(value, "0"));
    else if (!strcasecmp(key, "packet_file")) {
      if (*value == '/') snprintf(cfg->packet_file, sizeof(cfg->packet_file), "%s", value);
      else {
        char directory[PATH_MAX];
        parent_dir(path, directory, sizeof(directory));
        if (snprintf(cfg->packet_file, sizeof(cfg->packet_file), "%s/%s", directory, value) >=
            (int)sizeof(cfg->packet_file))
          die("packet_file path is too long");
      }
    }
  }
  fclose(file);
}

static int valid_proxy(const char *proxy) {
  if (!*proxy) return 1;
  const char *prefix = !strncasecmp(proxy, "http://", 7) ? proxy + 7 :
                       !strncasecmp(proxy, "socks5://", 9) ? proxy + 9 : NULL;
  if (!prefix || !*prefix || strchr(prefix, '@') || strchr(prefix, '/') || strchr(prefix, ' ')) return 0;
  const char *colon = strrchr(prefix, ':');
  if (!colon || colon == prefix || !colon[1]) return 0;
  char *end = NULL;
  long port = strtol(colon + 1, &end, 10);
  return *end == '\0' && port > 0 && port <= 65535;
}

static void executable_dir(char *out, size_t out_size) {
  ssize_t length = readlink("/proc/self/exe", out, out_size - 1);
  if (length < 0 || (size_t)length >= out_size - 1) die("cannot resolve launcher path");
  out[length] = '\0';
  parent_dir(out, out, out_size);
}

static const char *find_discord(void) {
  const char *override = getenv("DISCORD_DROVER_DISCORD_BIN");
  if (override && *override) return override;
  static const char *candidates[] = {
    "/usr/bin/discord", "/usr/bin/discord-canary", "/usr/bin/discord-ptb", "/usr/share/discord/Discord", NULL};
  for (size_t i = 0; candidates[i]; i++) if (access(candidates[i], X_OK) == 0) return candidates[i];
  return NULL;
}

int main(int argc, char **argv) {
  char path[PATH_MAX];
  config_path(path, sizeof(path));
  struct config cfg;
  load_config(&cfg, path);
  if (!valid_proxy(cfg.proxy)) die("proxy must be an unauthenticated http://host:port or socks5://host:port URL");

  const char *discord = find_discord();
  if (!discord) die("Discord was not found; set DISCORD_DROVER_DISCORD_BIN to its executable");

  char directory[PATH_MAX], preload[PATH_MAX * 2];
  executable_dir(directory, sizeof(directory));
  snprintf(preload, sizeof(preload), "%s/../lib/discord-drover/libdiscord-drover-preload.so", directory);
  if (access(preload, R_OK) != 0) {
    snprintf(preload, sizeof(preload), "%s/libdiscord-drover-preload.so", directory);
    if (access(preload, R_OK) != 0) die("preload library is missing; build or install the project first");
  }

  const char *old_preload = getenv("LD_PRELOAD");
  char combined_preload[PATH_MAX * 3];
  snprintf(combined_preload, sizeof(combined_preload), "%s%s%s", preload,
           old_preload && *old_preload ? ":" : "", old_preload && *old_preload ? old_preload : "");
  if (setenv("LD_PRELOAD", combined_preload, 1) != 0) die("cannot set LD_PRELOAD");
  setenv("DISCORD_DROVER_UDP_BYPASS", cfg.udp_bypass ? "1" : "0", 1);
  if (*cfg.packet_file) setenv("DISCORD_DROVER_PACKET", cfg.packet_file, 1);
  else unsetenv("DISCORD_DROVER_PACKET");
  if (*cfg.proxy) {
    setenv("http_proxy", cfg.proxy, 1);
    setenv("https_proxy", cfg.proxy, 1);
  }

  int extra = cfg.proxy[0] ? 1 : 0;
  char **command = calloc((size_t)argc + 1 + (size_t)extra, sizeof(*command));
  if (!command) die("out of memory");
  int at = 0;
  command[at++] = (char *)discord;
  if (extra) {
    size_t length = strlen("--proxy-server=") + strlen(cfg.proxy) + 1;
    command[at] = malloc(length);
    if (!command[at]) die("out of memory");
    snprintf(command[at++], length, "--proxy-server=%s", cfg.proxy);
  }
  for (int i = 1; i < argc; i++) command[at++] = argv[i];
  command[at] = NULL;
  execv(discord, command);
  perror(discord);
  return EXIT_FAILURE;
}
