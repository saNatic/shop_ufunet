#!/bin/bash

# 快速部署脚本 - 用于在服务器上快速部署新站点
# 使用预构建的镜像，实现秒级部署

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 显示使用说明
show_usage() {
    cat << EOF
使用方法:
  $0 <站点名称>

示例:
  $0 site1        # 部署站点1
  $0 site2        # 部署站点2
  $0 shop-test    # 部署测试商城

说明:
  - 站点名称将用作项目名称和容器前缀
  - 会自动创建对应的 .env 文件
  - 需要手动编辑 .env 文件设置端口号等参数
EOF
}

# 检查参数
if [ -z "$1" ]; then
    log_error "缺少站点名称参数"
    echo ""
    show_usage
    exit 1
fi

SITE_NAME=$1
ENV_FILE=".env.${SITE_NAME}"

log_info "============================================"
log_info "开始部署站点: $SITE_NAME"
log_info "============================================"
echo ""

# 步骤1: 检查环境变量模板
log_step "1/7 检查环境变量模板..."
if [ ! -f "env.multisite.example" ]; then
    log_error "找不到 env.multisite.example 模板文件"
    exit 1
fi

# 步骤2: 创建或检查环境变量文件
log_step "2/7 准备环境变量文件..."
if [ -f "$ENV_FILE" ]; then
    log_warn "环境变量文件 $ENV_FILE 已存在"
    read -p "是否使用现有配置？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "正在备份现有配置..."
        cp "$ENV_FILE" "$ENV_FILE.backup.$(date +%Y%m%d%H%M%S)"
        log_info "正在创建新配置..."
        cp env.multisite.example "$ENV_FILE"

        log_warn "请编辑 $ENV_FILE 文件，修改以下配置："
        log_warn "  1. COMPOSE_PROJECT_NAME=beikeshop_${SITE_NAME}"
        log_warn "  2. APP_CODE_PATH_HOST (项目代码路径)"
        log_warn "  3. DATA_PATH_HOST (数据存储路径)"
        log_warn "  4. 所有端口号 (避免与其他站点冲突)"
        log_warn "  5. 数据库配置 (密码、数据库名等)"
        log_warn "  6. REGISTRY (镜像仓库地址)"
        echo ""
        read -p "配置完成后按回车继续..."
    fi
else
    log_info "正在从模板创建环境变量文件..."
    cp env.multisite.example "$ENV_FILE"

    # 自动替换项目名称
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/beikeshop_site1/beikeshop_${SITE_NAME}/g" "$ENV_FILE"
        sed -i '' "s|../www/site1/|../www/${SITE_NAME}/|g" "$ENV_FILE"
        sed -i '' "s|data/site1|data/${SITE_NAME}|g" "$ENV_FILE"
    else
        # Linux
        sed -i "s/beikeshop_site1/beikeshop_${SITE_NAME}/g" "$ENV_FILE"
        sed -i "s|../www/site1/|../www/${SITE_NAME}/|g" "$ENV_FILE"
        sed -i "s|data/site1|data/${SITE_NAME}|g" "$ENV_FILE"
    fi

    log_warn "已创建配置文件: $ENV_FILE"
    log_warn "请编辑此文件，重点检查以下配置："
    log_warn "  1. 所有端口号 (NGINX_HOST_HTTP_PORT, MYSQL_PORT, REDIS_PORT 等)"
    log_warn "  2. 数据库密码 (MYSQL_ROOT_PASSWORD, MYSQL_PASSWORD)"
    log_warn "  3. REGISTRY (镜像仓库地址)"
    log_warn "  4. APP_CODE_PATH_HOST (确保项目代码已存在)"
    echo ""
    read -p "配置完成后按回车继续..."
fi

# 加载环境变量
source "$ENV_FILE"

# 步骤3: 检查镜像仓库配置
log_step "3/7 检查镜像仓库配置..."
if [ -z "$REGISTRY" ] || [ "$REGISTRY" = "localhost" ]; then
    log_error "请在 $ENV_FILE 中设置镜像仓库地址 REGISTRY"
    exit 1
fi
log_info "镜像仓库: $REGISTRY"
log_info "镜像标签: ${IMAGE_TAG:-latest}"

# 步骤4: 检查项目代码目录
log_step "4/7 检查项目代码目录..."
if [ ! -d "$APP_CODE_PATH_HOST" ]; then
    log_warn "项目代码目录不存在: $APP_CODE_PATH_HOST"
    read -p "是否创建此目录？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$APP_CODE_PATH_HOST"
        log_info "已创建目录: $APP_CODE_PATH_HOST"
        log_warn "请将项目代码放入此目录后再继续"
        exit 0
    else
        log_error "项目代码目录不存在，无法继续部署"
        exit 1
    fi
fi

# 步骤5: 登录镜像仓库并拉取镜像
log_step "5/7 拉取 Docker 镜像..."
log_info "正在登录镜像仓库..."
if ! docker login $REGISTRY; then
    log_error "登录失败，请检查镜像仓库地址和凭证"
    exit 1
fi

log_info "正在拉取镜像（首次拉取需要几分钟）..."
if docker-compose --env-file "$ENV_FILE" -f docker-compose.multisite.yml pull; then
    log_info "镜像拉取成功"
else
    log_error "镜像拉取失败"
    exit 1
fi

# 步骤6: 启动容器
log_step "6/7 启动 Docker 容器..."
if docker-compose --env-file "$ENV_FILE" -f docker-compose.multisite.yml up -d; then
    log_info "容器启动成功"
else
    log_error "容器启动失败"
    exit 1
fi

# 步骤7: 显示部署信息
log_step "7/7 部署完成！"
echo ""
log_info "============================================"
log_info "站点 $SITE_NAME 部署成功！"
log_info "============================================"
echo ""
log_info "访问信息："
log_info "  HTTP 地址:    http://localhost:${NGINX_HOST_HTTP_PORT}"
log_info "  HTTPS 地址:   https://localhost:${NGINX_HOST_HTTPS_PORT}"
log_info "  MySQL 端口:   ${MYSQL_PORT}"
log_info "  Redis 端口:   ${REDIS_PORT}"
log_info "  phpMyAdmin:   http://localhost:${PMA_PORT}"
echo ""
log_info "管理命令："
log_info "  查看日志:     docker-compose --env-file $ENV_FILE -f docker-compose.multisite.yml logs -f"
log_info "  停止站点:     docker-compose --env-file $ENV_FILE -f docker-compose.multisite.yml stop"
log_info "  启动站点:     docker-compose --env-file $ENV_FILE -f docker-compose.multisite.yml start"
log_info "  重启站点:     docker-compose --env-file $ENV_FILE -f docker-compose.multisite.yml restart"
log_info "  删除站点:     docker-compose --env-file $ENV_FILE -f docker-compose.multisite.yml down"
log_info "  进入容器:     docker-compose --env-file $ENV_FILE -f docker-compose.multisite.yml exec workspace bash"
echo ""
log_info "数据库信息："
log_info "  数据库名:     ${MYSQL_DATABASE}"
log_info "  用户名:       ${MYSQL_USER}"
log_info "  密码:         ${MYSQL_PASSWORD}"
log_info "  Root密码:     ${MYSQL_ROOT_PASSWORD}"
echo ""
log_warn "后续步骤："
log_warn "  1. 访问网站完成安装配置"
log_warn "  2. 如需安装依赖: docker-compose --env-file $ENV_FILE -f docker-compose.multisite.yml exec workspace composer install"
log_warn "  3. 如需运行迁移: docker-compose --env-file $ENV_FILE -f docker-compose.multisite.yml exec workspace php artisan migrate"
