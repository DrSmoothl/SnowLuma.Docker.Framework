#!/usr/bin/env bash
set -euo pipefail

: "${VNC_PASSWD:=vncpasswd}"
: "${SNOWLUMA_UID:=1000}"
: "${SNOWLUMA_GID:=1000}"
: "${SNOWLUMA_HOME:=/app/snowluma}"
: "${SNOWLUMA_DATA:=/app/snowluma-data}"
: "${SNOWLUMA_WEBUI_PORT:=5099}"
: "${SNOWLUMA_LOG_LEVEL:=info}"
: "${SNOWLUMA_SCREEN:=1920x1080x16}"

export DISPLAY="${DISPLAY:-:1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/snowluma-${SNOWLUMA_UID}}"
export SNOWLUMA_HOOK_RUNTIME_DIR="${SNOWLUMA_HOOK_RUNTIME_DIR:-${XDG_RUNTIME_DIR}}"
export SNOWLUMA_LOG_LEVEL

DISPLAY_NUM="${DISPLAY#:}"
DISPLAY_NUM="${DISPLAY_NUM%%.*}"

chmod 1777 /tmp || true
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix || true
rm -f /run/dbus/pid "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}"

mkdir -p \
  /var/run/dbus \
  /root/.vnc \
  "${XDG_RUNTIME_DIR}" \
  "${SNOWLUMA_DATA}/config" \
  /app/.cache \
  /app/.config \
  /app/.local/share

groupmod -o -g "${SNOWLUMA_GID}" snowluma
usermod -o -u "${SNOWLUMA_UID}" -g "${SNOWLUMA_GID}" snowluma

chown -R "${SNOWLUMA_UID}:${SNOWLUMA_GID}" \
  /app \
  /opt/QQ \
  "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

# Docker restart can preserve stale AF_UNIX socket nodes in the container
# writable layer. Remove them before QQ starts so PID reuse cannot make a dead
# hook socket look like a live SnowLuma injection.
find "${XDG_RUNTIME_DIR}" -maxdepth 1 -type s -name 'mojo.*.*.sock' -delete 2>/dev/null || true

node <<'NODE'
const fs = require('fs');
const path = require('path');

const dataDir = process.env.SNOWLUMA_DATA || '/app/snowluma-data';
const configDir = path.join(dataDir, 'config');
const runtimeConfigPath = path.join(configDir, 'runtime.json');
const requestedPort = Number(process.env.SNOWLUMA_WEBUI_PORT || 5099);
const webuiPort = Number.isInteger(requestedPort) && requestedPort > 0 && requestedPort <= 65535
  ? requestedPort
  : 5099;

fs.mkdirSync(configDir, { recursive: true });

let runtimeConfig = {};
try {
  runtimeConfig = JSON.parse(fs.readFileSync(runtimeConfigPath, 'utf8'));
} catch {
  runtimeConfig = {};
}

runtimeConfig.webuiPort = webuiPort;
fs.writeFileSync(runtimeConfigPath, `${JSON.stringify(runtimeConfig, null, 2)}\n`, 'utf8');
NODE

x11vnc -storepasswd "${VNC_PASSWD}" /root/.vnc/passwd >/dev/null

wait_for_xvfb() {
  local socket="/tmp/.X11-unix/X${DISPLAY_NUM}"

  for _ in {1..200}; do
    if [ -S "${socket}" ]; then
      return 0
    fi

    if ! kill -0 "${XVFB_PID}" 2>/dev/null; then
      echo "Xvfb exited before display ${DISPLAY} became ready." >&2
      return 1
    fi

    sleep 0.1
  done

  echo "Timed out waiting for Xvfb display ${DISPLAY}." >&2
  return 1
}

dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address &
Xvfb "${DISPLAY}" -screen 0 "${SNOWLUMA_SCREEN}" &
XVFB_PID=$!
wait_for_xvfb

fluxbox &
x11vnc -display "${DISPLAY}" -noxrecord -noxfixes -noxdamage -forever -rfbauth /root/.vnc/passwd &
X11VNC_PID=$!
sleep 0.5
if ! kill -0 "${X11VNC_PID}" 2>/dev/null; then
  echo "x11vnc failed to start for display ${DISPLAY}." >&2
  exit 1
fi

nohup /opt/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen 6081 --file-only >/var/log/novnc.log 2>&1 &

exec supervisord -c /etc/supervisord.conf
