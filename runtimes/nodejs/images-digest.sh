#!/bin/bash

USER="admin"
PASS="passw0rd"

read -p "请输入私有仓库地址（必填）：" REGISTRY
if [ -z "$REGISTRY" ]; then
    echo "❌ 你没有输入任何内容，脚本停止执行！"
    exit 1
fi

# 删除 runtime-node
echo "删除 runtime-node:latest..."
DIGEST=$(curl --noproxy "*" -s -X GET http://$REGISTRY/v2/lafyun/runtime-node/manifests/latest \
  --user $USER:$PASS \
  --header "Accept: application/vnd.docker.distribution.manifest.v2+json" 2>&1 | grep -i Docker-Content-Digest | awk '{print $2}')

if [ -n "$DIGEST" ]; then
    curl --noproxy "*" -X DELETE http://$REGISTRY/v2/lafyun/runtime-node/manifests/$DIGEST --user $USER:$PASS
    echo "✅ 已删除"
else
    echo "⚠️ 未找到 digest"
fi

# 删除 runtime-node-init
echo "删除 runtime-node-init:latest..."
DIGEST=$(curl --noproxy "*" -s -X GET http://$REGISTRY/v2/lafyun/runtime-node-init/manifests/latest \
  --user $USER:$PASS \
  --header "Accept: application/vnd.docker.distribution.manifest.v2+json" 2>&1 | grep -i Docker-Content-Digest | awk '{print $2}')

if [ -n "$DIGEST" ]; then
    curl --noproxy "*" -X DELETE http://$REGISTRY/v2/lafyun/runtime-node-init/manifests/$DIGEST --user $USER:$PASS
    echo "✅ 已删除"
else
    echo "⚠️ 未找到 digest"
fi

echo "完成"
