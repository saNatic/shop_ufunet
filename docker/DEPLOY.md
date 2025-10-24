# 部署配置修改指南

本文档说明如何在本地构建镜像并推送到镜像仓库，以及在服务器上基于 `env.example`/`env.multisite.example` 调整配置，从而在同一台服务器部署多个站点。

---

## 1. 本地构建并推送镜像

1. 复制环境模板并检查关键变量：
   ```bash
   cp env.example .env
   ```
   需要确认/修改的字段：
   - `REGISTRY`：镜像仓库地址，例如 `registry.cn-hangzhou.aliyuncs.com/your-namespace`
   - `IMAGE_TAG`：镜像版本标签，可用日期或版本号区分，例如 `20240215`
   - `COMPOSE_PROJECT_NAME`：决定镜像默认前缀，保持与服务器使用的前缀一致会更直观
   - 若代码路径不在 `../www/`，同步调整 `APP_CODE_PATH_HOST`

2. 构建镜像（可根据需要选择全部或部分服务）：
   ```bash
   docker compose --env-file .env -f docker-compose.build.yml build
   ```
   也可以使用 `./build-and-push.sh` 脚本，它会先检查配置再执行构建与推送。

3. 登录并推送镜像：
   ```bash
   docker login $REGISTRY
   docker compose --env-file .env -f docker-compose.build.yml push
   ```
   构建完成后，会得到以下镜像（示例）：
   - `$REGISTRY/beikeshop-nginx:$IMAGE_TAG`
   - `$REGISTRY/beikeshop-php-fpm:$IMAGE_TAG`
   - `$REGISTRY/beikeshop-php-worker:$IMAGE_TAG`
   - `$REGISTRY/beikeshop-laravel-horizon:$IMAGE_TAG`
   - `$REGISTRY/beikeshop-workspace:$IMAGE_TAG`（可选，不需要 SSH/WebIDE 功能可不部署）

> ⚠️ 默认情况下，MySQL 与 Redis 在生产环境使用官方镜像（`mysql:<版本>` 与 `redis:alpine`），无需在本地构建。

---

## 2. 服务器端环境配置（多项目场景）

1. 为每个站点复制一份环境文件：
   ```bash
   cp env.multisite.example .env.<站点名>
   ```
   站点名建议与域名或项目代号一致，例如 `.env.shop`。

2. 在新文件中必须检查或修改的字段：
   - `COMPOSE_PROJECT_NAME`：容器名前缀，需在同一服务器保持唯一，例如 `beikeshop_shop`
   - `APP_CODE_PATH_HOST`：项目代码目录，部署前需将代码同步到该路径
   - `DATA_PATH_HOST`：持久化数据目录，用于存放 MySQL/Redis 数据，建议为每个站点单独目录
   - `REGISTRY` / `IMAGE_TAG`：与本地构建时保持一致，确保能拉取对应镜像
   - 端口类变量（避免端口冲突）：
     - `NGINX_HOST_HTTP_PORT` / `NGINX_HOST_HTTPS_PORT`
     - `MYSQL_PORT`
     - `REDIS_PORT`
     - `WORKSPACE_SSH_PORT`（如需启用 workspace 容器）
     - `PMA_PORT`、`REDIS_WEBUI_PORT`（如启用管理工具）
   - 数据库凭据：
     - `MYSQL_DATABASE`、`MYSQL_USER`、`MYSQL_PASSWORD`
     - `MYSQL_ROOT_PASSWORD`
     - `MYSQL_ENTRYPOINT_INITDB`（如需要挂载初始化 SQL 脚本）
   - Redis 凭据：`REDIS_PASSWORD`

3. 登录镜像仓库并启动：
   ```bash
   docker login $REGISTRY
   docker compose --env-file .env.<站点名> -f docker-compose.multisite.yml pull
   docker compose --env-file .env.<站点名> -f docker-compose.multisite.yml up -d
   ```

4. 查看运行情况与日志：
   ```bash
   docker compose --env-file .env.<站点名> -f docker-compose.multisite.yml ps
   docker compose --env-file .env.<站点名> -f docker-compose.multisite.yml logs -f
   ```

---

## 3. 多项目部署建议

- 为每个站点使用独立的 `.env.<站点名>` 文件和独立的数据目录，保证资源隔离。
- 同一个仓库可以复用同一套镜像，只需通过 `IMAGE_TAG` 区分版本；升级时建议新建标签并在对应 `.env` 中切换。
- 如果不需要某些辅助容器（如 `workspace`、`phpmyadmin`、`redis-webui`），可以在 `docker-compose.multisite.yml` 中通过 `profiles` 控制或直接移除对应服务。
- 部署完成后，使用反向代理或负载均衡（如 Nginx/Traefik）将外部端口路由到各站点的 HTTP/HTTPS 端口。

---

如需进一步定制（例如增加新服务、挂载证书、配置健康检查），可在 `docker-compose.multisite.yml` 基础上继续扩展，但记得同步更新对应的环境变量模板。欢迎在修改前备份原始文件，便于快速回滚。了解最新的 Compose 配置与命令，可参考官方文档：<https://docs.docker.com/compose/>。
