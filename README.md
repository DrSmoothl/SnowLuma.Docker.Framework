# SnowLuma.Docker.Framework

SnowLuma 的 Linux Docker 运行框架，结构参考 `NapCat.Docker.Framework`：容器内安装 Linux QQ、Xvfb、VNC/noVNC、supervisord，并运行 SnowLuma 的 Node.js 发行产物。

## 支持平台

- [x] Linux/Amd64
- [x] Linux/Arm64

## 端口

- `5900`: VNC
- `6081`: noVNC
- `5099`: SnowLuma WebUI
- `3000`: OneBot HTTP 默认端口
- `3001`: OneBot WebSocket 默认端口

## 预编译产物

这个 Docker 框架不编译 SnowLuma 源码，只接收已经编译好的发行包。

把预编译产物命名为 `SnowLuma.Framework.tar.gz`，放到 Docker 仓库根目录：

```text
SnowLuma.Framework.tar.gz
├── index.mjs
├── package.json
├── client/index.html
└── native/
    ├── snowluma-linux-x64.node
    ├── snowluma-linux-x64.so
    ├── snowluma-linux-arm64.node
    ├── snowluma-linux-arm64.so
    ├── websocket-linux-x64.node
    └── websocket-linux-arm64.node
```

## 本地构建

默认本地构建 `linux/amd64` 并加载到本地 Docker：

```bash
./scripts/build-image.sh
```

它会校验仓库根目录的 `SnowLuma.Framework.tar.gz`，然后构建 Docker 镜像 `snowluma-docker-framework:latest`。

发布 multi-arch 镜像推荐使用 GitHub Actions。workflow 会在原生 `ubuntu-22.04` 和 `ubuntu-22.04-arm` runner 上分别构建 amd64/arm64 镜像，再合并 manifest。

本地也可以用 buildx push，但是否使用模拟取决于你的本地 buildx/binfmt 环境：

```bash
IMAGE=motricseven7/snowluma:latest PUSH=1 ./scripts/build-image.sh
```

## 启动

```bash
./scripts/run.sh
```

或使用已发布镜像：

```bash
docker compose up -d
```

## docker run 示例

```bash
docker run -d \
  --name snowluma \
  --restart unless-stopped \
  --shm-size=1g \
  --cap-add=SYS_PTRACE \
  --security-opt seccomp=unconfined \
  -e VNC_PASSWD=vncpasswd \
  -e SNOWLUMA_WEBUI_PORT=5099 \
  -p 5900:5900 \
  -p 6081:6081 \
  -p 5099:5099 \
  -p 3000:3000 \
  -p 3001:3001 \
  -v snowluma-data:/app/snowluma-data \
  -v snowluma-qq-config:/app/.config \
  -v snowluma-qq-data:/app/.local/share \
  motricseven7/snowluma:latest
```

## 常用命令

进入容器：

```bash
docker exec -it snowluma bash
```

查看日志：

```bash
docker logs -f snowluma
```

查看 SnowLuma WebUI 临时密码：

```bash
docker logs snowluma | grep "临时密码"
```

noVNC 地址：

```text
http://IP:6081/
```

SnowLuma WebUI 地址：

```text
http://IP:5099/
```

SnowLuma 的配置和 OneBot 配置默认持久化在 `/app/snowluma-data/config`。

## 注意

SnowLuma 当前使用 native addon 对 QQ 进程进行加载，容器启动时需要 `SYS_PTRACE` 能力和 `seccomp=unconfined`。请遵守第三方软件的使用许可和开源协议。
