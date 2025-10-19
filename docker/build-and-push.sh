#!/bin/bash

# 构建并推送 Docker 镜像到镜像仓库
# 用途：在开发机器上构建一次镜像，推送到仓库，其他服务器直接拉取使用

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 .env 文件
if [ ! -f .env ]; then
    log_error ".env 文件不存在，请先创建配置文件"
    exit 1
fi

# 加载环境变量
source .env

# 检查必要的环境变量
if [ -z "$REGISTRY" ] || [ "$REGISTRY" = "localhost" ]; then
    log_error "请在 .env 文件中设置镜像仓库地址 REGISTRY"
    log_info "例如: REGISTRY=registry.cn-hangzhou.aliyuncs.com/your-namespace"
    exit 1
fi

# 设置默认镜像标签
IMAGE_TAG=${IMAGE_TAG:-latest}

log_info "镜像仓库: $REGISTRY"
log_info "镜像标签: $IMAGE_TAG"
log_info ""

# 询问用户是否继续
read -p "是否继续构建并推送镜像？(y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "已取消操作"
    exit 0
fi

# 登录镜像仓库
log_info "正在登录镜像仓库..."
if ! docker login $REGISTRY; then
    log_error "登录失败，请检查镜像仓库地址和凭证"
    exit 1
fi

# 构建镜像
log_info "开始构建镜像..."
log_info "这可能需要 10-30 分钟，具体取决于网络速度和机器性能..."
echo ""

if docker-compose -f docker-compose.build.yml build; then
    log_info "镜像构建成功！"
else
    log_error "镜像构建失败"
    exit 1
fi

echo ""
log_info "开始推送镜像到仓库..."

if docker-compose -f docker-compose.build.yml push; then
    log_info "镜像推送成功！"
else
    log_error "镜像推送失败"
    exit 1
fi

echo ""
log_info "============================================"
log_info "所有镜像已成功构建并推送到仓库！"
log_info "============================================"
log_info ""
log_info "已推送的镜像列表："
log_info "  - $REGISTRY/beikeshop-nginx:$IMAGE_TAG"
log_info "  - $REGISTRY/beikeshop-php-fpm:$IMAGE_TAG"
log_info "  - $REGISTRY/beikeshop-workspace:$IMAGE_TAG"
log_info "  - $REGISTRY/beikeshop-php-worker:$IMAGE_TAG"
log_info "  - $REGISTRY/beikeshop-laravel-horizon:$IMAGE_TAG"
log_info ""
log_info "现在可以在其他服务器上使用这些镜像快速部署了！"
log_info "部署方法请参考 DEPLOY.md 文档"
