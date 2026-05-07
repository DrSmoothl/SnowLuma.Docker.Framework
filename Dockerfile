# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-bookworm-slim

ARG TARGETARCH=amd64
ARG QQ_VERSION=3.2.28-48517
ARG QQ_CHANNEL=f9cbaab2
ARG QQ_BASE_URL=https://dldir1v6.qq.com/qqfile/qq/QQNT

ENV DEBIAN_FRONTEND=noninteractive \
    VNC_PASSWD=vncpasswd \
    TZ=Asia/Shanghai \
    SNOWLUMA_HOME=/app/snowluma \
    SNOWLUMA_DATA=/app/snowluma-data \
    SNOWLUMA_WEBUI_PORT=5099 \
    SNOWLUMA_UID=1000 \
    SNOWLUMA_GID=1000 \
    SNOWLUMA_LOG_LEVEL=info \
    SNOWLUMA_SCREEN=1920x1080x16 \
    DISPLAY=:1

RUN rm -f /etc/apt/apt.conf.d/docker-clean; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      aria2 \
      ca-certificates \
      curl \
      dbus-user-session \
      ffmpeg \
      fluxbox \
      fonts-wqy-zenhei \
      git \
      gnutls-bin \
      libasound2 \
      libatspi2.0-0 \
      libgbm1 \
      libgtk-3-0 \
      libnotify4 \
      libnss3 \
      libsecret-1-0 \
      openbox \
      procps \
      supervisor \
      tzdata \
      unzip \
      x11vnc \
      xdg-utils \
      xorg \
      xvfb && \
    echo "${TZ}" > /etc/timezone && \
    ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
    cd /opt && git clone --depth=1 https://github.com/novnc/noVNC.git && \
    cd /opt/noVNC/utils && git clone --depth=1 https://github.com/novnc/websockify.git && \
    cp /opt/noVNC/vnc.html /opt/noVNC/index.html && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    case "${TARGETARCH}" in \
      amd64|arm64) qq_arch="${TARGETARCH}" ;; \
      *) echo "Unsupported Docker target architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    apt-get update && \
    aria2c --check-certificate=false -x16 -s16 -o /tmp/linuxqq.deb "${QQ_BASE_URL}/${QQ_CHANNEL}/linuxqq_${QQ_VERSION}_${qq_arch}.deb" && \
    (dpkg -i /tmp/linuxqq.deb || apt-get -f install -y --no-install-recommends) && \
    rm -f /tmp/linuxqq.deb && \
    chmod 777 /opt/QQ && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY SnowLuma.Framework.tar.gz /tmp/SnowLuma.Framework.tar.gz
COPY supervisord.conf /etc/supervisord.conf
COPY start.sh /root/start.sh

RUN chmod +x /root/start.sh && \
    groupadd --gid 1001 snowluma && \
    useradd --no-log-init --uid 1001 --gid 1001 --home-dir /app --shell /bin/bash snowluma && \
    mkdir -p "${SNOWLUMA_HOME}" "${SNOWLUMA_DATA}" /app/.cache /app/.config /app/.local/share && \
    tar -xzf /tmp/SnowLuma.Framework.tar.gz -C "${SNOWLUMA_HOME}" && \
    case "${TARGETARCH}" in \
      amd64) native_arch="x64" ;; \
      arm64) native_arch="arm64" ;; \
      *) echo "Unsupported Docker target architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    test -f "${SNOWLUMA_HOME}/index.mjs" && \
    test -f "${SNOWLUMA_HOME}/native/snowluma-linux-${native_arch}.node" && \
    test -f "${SNOWLUMA_HOME}/native/snowluma-linux-${native_arch}.so" && \
    test -f "${SNOWLUMA_HOME}/native/websocket-linux-${native_arch}.node" && \
    rm -f /tmp/SnowLuma.Framework.tar.gz && \
    chown -R snowluma:snowluma /app /opt/QQ

WORKDIR /app/snowluma-data

EXPOSE 5900 6081 5099 3000 3001

VOLUME ["/app/snowluma-data", "/app/.config", "/app/.local/share"]

CMD ["/root/start.sh"]
