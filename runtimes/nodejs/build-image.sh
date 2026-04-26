#!/bin/bash
# Warning: just for development phase, will be move to github action in future.

set -e  # 遇到错误立即退出

# ===================== 交互输入 =====================
echo "===== 镜像构建脚本 ====="

# 1. 输入私有仓库地址（必填）
read -p "请输入私有仓库地址（不输入默认 ttl.sh）：" REGISTRY

# 判断仓库地址是否为空
if [ -z "$REGISTRY" ]; then
    REGISTRY="ttl.sh"
fi

# 2. 输入版本号（可选，默认 latest）
read -p "请输入版本号（不输入默认 latest）：" VERSION

# 如果没输入 version，赋值为 latest
if [ -z "$VERSION" ]; then
    VERSION="latest"
fi

# 3. 如果是 ttl.sh，自动添加时效后缀（避免覆盖）
if [ "$REGISTRY" = "ttl.sh" ]; then
    TIMESTAMP=$(date +%s)
    VERSION="${VERSION}-${TIMESTAMP}"
    echo "⚠️  ttl.sh 不支持覆盖，自动添加时间戳: $VERSION"
fi

echo "========================================"
echo "✅ 仓库地址：$REGISTRY"
echo "✅ 版本号：$VERSION"
echo "========================================"
echo "开始构建镜像..."

# ===================== 构建镜像 =====================
# 检查 buildx 是否可用
if ! docker buildx ls | grep -q "default"; then
    echo "⚠️  创建 buildx 构建器..."
    docker buildx create --name mybuilder --use
    docker buildx inspect --bootstrap
fi

# build main image
echo "📦 构建 runtime-node:${VERSION}..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --push \
    -t ${REGISTRY}/lafyun/runtime-node:${VERSION} \
    -f Dockerfile .

# build init image
echo "📦 构建 runtime-node-init:${VERSION}..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --push \
    -t ${REGISTRY}/lafyun/runtime-node-init:${VERSION} \
    -f Dockerfile.init .

# ===================== 验证推送结果 =====================
echo "========================================"
echo "✅ 镜像构建并推送完成！"
echo ""
echo "📌 镜像地址："
echo "   - ${REGISTRY}/lafyun/runtime-node:${VERSION}"
echo "   - ${REGISTRY}/lafyun/runtime-node-init:${VERSION}"
echo ""

# 如果不是 ttl.sh，尝试验证拉取
if [ "$REGISTRY" != "ttl.sh" ]; then
    echo "🔍 验证镜像是否可拉取..."
    docker pull ${REGISTRY}/lafyun/runtime-node:${VERSION} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ 验证成功：镜像已存在于仓库"
    else
        echo "⚠️  验证失败：无法拉取镜像（可能是私有仓库权限问题）"
    fi
fi

echo "🎉 脚本执行完毕！"
