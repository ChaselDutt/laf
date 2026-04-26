#!/bin/bash
# Warning: just for development phase, will be move to github action in future.

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

echo "========================================"
echo "✅ 仓库地址：$REGISTRY"
echo "✅ 版本号：$VERSION"
echo "========================================"
echo "开始构建镜像..."

# ===================== 构建镜像 =====================
# build main image
# docker buildx build --platform linux/amd64,linux/arm64 --push -t docker.io/lafyun/runtime-node:$version -f Dockerfile .
docker buildx build --platform linux/amd64,linux/arm64 --push -t ${REGISTRY}/lafyun/runtime-node:${VERSION} -f Dockerfile .

# build init image
# docker buildx build --platform linux/amd64,linux/arm64 --push -t docker.io/lafyun/runtime-node-init:$version -f Dockerfile.init .
docker buildx build --platform linux/amd64,linux/arm64 --push -t ${REGISTRY}/lafyun/runtime-node-init:${VERSION} -f Dockerfile.init .

echo "🎉 构建完成！"
