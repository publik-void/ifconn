#!/bin/sh

ifconfig_command="/sbin/ifconfig"
ip_command="/usr/bin/ip"
ping_command="/bin/ping"
log_command="/usr/bin/logger"
log_command="printf \"%s\\n\""

interface="wlan0"

usage_msg="\
This is a shell script for easy Wi-Fi control intended for Raspberry Pis.

Usage:
  $0 connect     [interface]
  $0 disconnect  [interface]
  $0 reconnect   [interface]
  $0 autoconnect [interface]

…where \`interface\` is \`$interface\` by default.

\`connect\`/\`disconnect\` map to \`$ifconfig_command <interface> <up/down>\`, \
respectively.
\`reconnect\` issues a \`connect\` and then a \`disconnect\`.
\`autoconnect\` issues a \`reconnect\` iff the local gateway is not reachable.

The script makes use of \`$log_command\` for logging.

As a particular example, the \`autoconnect\` subcommand may help with issues \
where
the Pi looses the Wi-Fi connection and does not reconnect on its own. To
automatically reconnect every 5 minutes and turn Wi-Fi off during the night, put
the following in a root-privileged crontab:

*/5 9-19 * * * ifconn autoconnect
  5   20 * * * ifconn disconnect

…and make sure to replace \`ifconn\` by a path to this script if it is not
available on the \`\$PATH\`."

case $# in
  1) subcommand="$1" ;;
  2) subcommand="$1"; interface="$2" ;;
  *) printf "%s\n" "$usage_msg" >&2 ; exit 1 ;;
esac

log_msg="connection on $interface ${subcommand}ed via $0"

case "$subcommand" in
  "connect")
    eval "$ifconfig_command" "$interface" up || return $?
    eval "$log_command" "\"$log_msg\""
    ;;
  "disconnect")
    eval "$ifconfig_command" "$interface" || return $?
    eval "$log_command" "\"$log_msg\""
    ;;
  "reconnect")
    eval "$ifconfig_command" "$interface" down && \
    eval "$ifconfig_command" "$interface" up || return $?
    eval "$log_command" "\"$log_msg\""
    ;;
  "autoconnect")
    # Find default gateway, ping it, and reconnect interface if no response
    # Adapted in part from:
    # `https://forums.raspberrypi.com/viewtopic.php?t=239730`
    gateway=$(eval "$ip_command" -4 route show default dev "$interface" | \
      grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])' | \
      head -n 1)
    #printf "\`%s\`-ing gateway %s\n" "$ping_command" "$gateway" >&2
    if ! eval "$ping_command" -q -c10 "$gateway" > /dev/null 2>&1; then
      eval "$ifconfig_command" "$interface" down &&
      eval "$ifconfig_command" "$interface" up || return $?
      eval "$log_command" "\"$log_msg\""
    fi
    ;;
  *) printf "%s\n" "$usage_msg" >&2 ; exit 1 ;;
esac

