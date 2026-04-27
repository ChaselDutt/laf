#!/usr/bin/env sh
set -e

# Intro: start laf with sealos in linux
# Usage: sh ./install-on-linux.sh


printf "请选择镜像加速器（留空则不配置）："
printf "1)  DaoCloud 加速器 (docker.m.daocloud.io)"
printf "2)  轩辕镜像 (docker.xuanyuan.me)"
printf "3)  毫秒镜像 (docker.1ms.run)"
printf "4)  阿里云杭州公共仓库 (registry.cn-hangzhou.aliyuncs.com)"
printf "5)  请输入数字 (1/2/3/4，直接回车则不配置)"
read ACCELERATOR_CHOICE

printf "请输入代理地址（留空则不设置代理）: "
read PROXYURL

printf "请输入绑定域名（默认127.0.0.1.nip.io）: "
read DOMAIN
# ==================== 设置代理 ====================
if [ -n "$PROXYURL" ]; then
    case "$PROXYURL" in
        http://*|https://*)
            ;;
        *)
            PROXYURL="http://$PROXYURL"
            ;;
    esac
    export http_proxy=$PROXYURL
    export https_proxy=$PROXYURL
    export HTTP_PROXY=$PROXYURL
    export HTTPS_PROXY=$PROXYURL
    export NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,192.168.0.0/16,sealos.hub,apiserver.cluster.local,.cluster.local,.nip.io
    export no_proxy=localhost,127.0.0.1,10.0.0.0/8,192.168.0.0/16,sealos.hub,apiserver.cluster.local,.cluster.local,.nip.io
    echo "代理已设置为: $PROXYURL"
else
    echo "跳过代理设置"
fi
# ====================绑定域名 ====================
if [ -z "$DOMAIN" ]; then
    DOMAIN="127.0.0.1.nip.io"
fi
# ==================== 安装 Sealos ====================
if [ -x "$(command -v apt)" ]; then
    echo "deb [trusted=yes] https://apt.fury.io/labring/ /" | tee /etc/apt/sources.list.d/labring.list
    apt update
    apt install iptables host -y
    apt install sealos=4.3.5 -y
    apt install jq -y
    apt install git -y
    # apt install podman -y
    # apt install skopeo -y
    sed -i "/update_etc_hosts/c \\ - ['update_etc_hosts', 'once-per-instance']" /etc/cloud/cloud.cfg && touch /var/lib/cloud/instance/sem/config_update_etc_hosts
fi

if [ -x "$(command -v yum)" ]; then
    cat > /etc/yum.repos.d/labring.repo << EOF
[fury]
name=labring Yum Repo
baseurl=https://yum.fury.io/labring/
enabled=1
gpgcheck=0
EOF
    yum clean all
    yum install -y bind-utils iptables
    yum install sealos=4.3.7 -y
    yum install jq -y
    yum install git -y
fi

ARCH=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/)
echo "ARCH: $ARCH"

if [ ! -x "$(command -v sealos)" ]; then
    echo "sealos not installed"
    exit 1
fi

echo "拉取仓库到 /laf"
if [ -d "/laf" ]; then
    echo "/laf 目录已存在，跳过 clone"
else
    git clone https://github.com/ChaselDutt/laf.git /laf
fi

# ==================== 设置镜像加速 ====================
if [ -n "$ACCELERATOR_CHOICE" ]; then
    case "$ACCELERATOR_CHOICE" in
        1)
            MIRROR_URL="docker.m.daocloud.io"
            echo "已选择: DaoCloud 加速器"
            ;;
        2)
            MIRROR_URL="docker.xuanyuan.me"
            echo "已选择: 轩辕镜像"
            ;;
        3)
            MIRROR_URL="docker.1ms.run"
            echo "已选择: 毫秒镜像"
            ;;
        4)
            MIRROR_URL="registry.cn-hangzhou.aliyuncs.com"
            echo "已选择: 阿里云杭州公共仓库"
            ;;
        *)
            echo "无效选择，跳过配置镜像加速器"
            ;;
    esac
    
    if [ -n "$MIRROR_URL" ]; then
        mkdir -p /etc/containers
        cat > /etc/containers/registries.conf << EOF
unqualified-search-registries = ["docker.io"]

[[registry]]
prefix = "docker.io"
location = "docker.io"

[[registry.mirror]]
location = "$MIRROR_URL"
EOF
        echo "镜像加速器已配置: $MIRROR_URL"
    fi
else
    echo "跳过镜像加速器配置"
fi

echo "构建 lafyun/laf:latest 镜像"
cd /laf/build
sealos build -t lafyun/laf:latest -f Kubefile .

# pull sealos cluster images

sealos pull labring/kubernetes:v1.24.9
sealos pull labring/flannel:v0.19.0
sealos pull labring/helm:v3.8.2
sealos pull labring/openebs:v1.9.0
sealos pull labring/cert-manager:v1.8.0
sealos pull labring/metrics-server:v0.6.2
# sealos pull lafyun/laf:latest 改成使用自构建镜像
sealos pull docker.io/labring/ingress-nginx:v1.8.1
sealos pull labring/kubeblocks:v0.7.1

# echo "镜像拉取结束取消代理"
# unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY

# install k8s cluster

sealos run labring/kubernetes:v1.24.9 labring/flannel:v0.19.0 labring/helm:v3.8.2

# taint master node

NODENAME=$(kubectl get nodes -ojsonpath='{.items[0].metadata.name}')
kubectl taint node $NODENAME node-role.kubernetes.io/master- || true
kubectl taint node $NODENAME node-role.kubernetes.io/control-plane- || true

# install required components

sealos run labring/openebs:v1.9.0
sealos run labring/cert-manager:v1.8.0
sealos run labring/metrics-server:v0.6.2
sealos run docker.io/labring/ingress-nginx:v1.8.1 \
  -e HELM_OPTS="--set controller.hostNetwork=true --set controller.kind=DaemonSet --set controller.service.enabled=false"
sealos run labring/kubeblocks:v0.7.1

echo "开始部署laf"
sealos run --env DOMAIN=$DOMAIN --env DB_PV_SIZE=5Gi --env OSS_PV_SIZE=5Gi --env EXTERNAL_HTTP_SCHEMA=http lafyun/laf:latest

echo "构建 runtime-node 镜像"
cd /laf/runtimes/nodejs

if [ ! -f "Dockerfile" ]; then
    echo "错误: Dockerfile 不存在"
    exit 1
fi

sealos build --network=host -t ttl.sh/lafyun/runtime-node:latest -f Dockerfile .
sealos build -t ttl.sh/lafyun/runtime-node-init:latest -f Dockerfile.init .

# 配置 insecure 仓库（如果需要）
if ! grep -q "sealos.hub:5000" /etc/containers/registries.conf 2>/dev/null; then
    echo "配置 sealos.hub:5000 为 insecure 仓库"
    cat >> /etc/containers/registries.conf << EOF
[[registry]]
location = "sealos.hub:5000"
insecure = true
EOF
fi

echo "登录私有仓库 sealos.hub:5000"
sealos login --tls-verify=false -u admin -p passw0rd sealos.hub:5000

echo "推送镜像到 sealos.hub:5000"
sealos tag ttl.sh/lafyun/runtime-node:latest sealos.hub:5000/lafyun/runtime-node:latest
sealos push --tls-verify=false sealos.hub:5000/lafyun/runtime-node:latest

sealos tag ttl.sh/lafyun/runtime-node-init:latest sealos.hub:5000/lafyun/runtime-node-init:latest
sealos push --tls-verify=false sealos.hub:5000/lafyun/runtime-node-init:latest

# 如果 crictl 可用，删除旧镜像
if command -v crictl >/dev/null 2>&1; then
    echo "删除 sealos.hub:5000 里的旧镜像"
    crictl rmi sealos.hub:5000/lafyun/runtime-node:latest || true
    crictl rmi sealos.hub:5000/lafyun/runtime-node-init:latest || true
fi

echo "部署完成！"
