#!/bin/bash
# 单架构构建脚本（仅 linux/amd64）

echo "===== 镜像构建脚本 ====="

# 1. 输入私有仓库地址
read -p "请输入私有仓库地址（不输入默认 ttl.sh）：" REGISTRY
if [ -z "$REGISTRY" ]; then
    REGISTRY="ttl.sh"
fi

# 2. 输入版本号
read -p "请输入版本号（不输入默认 latest）：" VERSION
if [ -z "$VERSION" ]; then
    VERSION="latest"
fi

# 3. 如果是 ttl.sh，自动添加时间戳避免覆盖
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

# 构建 main image（单架构，使用普通 docker build）
echo "📦 构建 runtime-node:${VERSION}..."
docker build -t ${REGISTRY}/lafyun/runtime-node:${VERSION} -f Dockerfile .

# 推送
echo "📤 推送镜像..."
docker push ${REGISTRY}/lafyun/runtime-node:${VERSION}

# 构建 init image
echo "📦 构建 runtime-node-init:${VERSION}..."
docker build -t ${REGISTRY}/lafyun/runtime-node-init:${VERSION} -f Dockerfile.init .

# 推送
docker push ${REGISTRY}/lafyun/runtime-node-init:${VERSION}

echo "🎉 构建完成！"
echo "📌 镜像地址："
echo "   - ${REGISTRY}/lafyun/runtime-node:${VERSION}"
echo "   - ${REGISTRY}/lafyun/runtime-node-init:${VERSION}"
