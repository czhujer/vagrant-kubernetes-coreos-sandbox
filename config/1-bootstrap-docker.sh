#!/usr/bin/env bash
set -euxo pipefail
IFS=$'\n\t'

if [[ $UID -ne 0 ]]; then
    echo "Restarting script as root"
    sudo bash "$0" "$@"
    exit $?
fi

# https://kubernetes.io/docs/setup/independent/install-kubeadm/#installing-runtime

apt-get update -qq
apt-get install -yq --no-install-recommends \
    jq=1.5+dfsg-2 \
    ipvsadm=1:1.28-3ubuntu0.18.04.1 \
    ipset=6.34-1 \
    net-tools=1.60+git20161116.90da8a0-1ubuntu1 \
    iotop=0.6-2 \
    traceroute=1:2.1.0-2 \
    tcpdump=4.9.2-3 \
    unzip=6.0-21ubuntu1

##########################################
echo "Disable swap"
##########################################

sed -i '/ swap / s/^/#/' /etc/fstab
swapoff -a


##########################################
echo "Enable memory and CPU accounting"
##########################################

# https://bugzilla.redhat.com/show_bug.cgi?id=1692131
cat <<'EOF' >> /etc/systemd/system.conf
DefaultMemoryAccounting=yes
DefaultCPUAccounting=yes
EOF
systemctl daemon-reexec


##########################################
echo "Installing Docker"
##########################################
#vagrant fix
DOCKER_VERSION="5:18.09.9~3-0~ubuntu-bionic"
# DOCKER_VERSION="${docker_version}"

apt-get install -yq --no-install-recommends \
    apt-transport-https \
    curl \
    ca-certificates=20180409 \
    software-properties-common=0.96.24.32.11 \
    gpg-agent=2.2.4-1ubuntu1.2

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable" 1>/dev/null

apt-get update -qq
apt-get install -yq --no-install-recommends \
    docker-ce="$DOCKER_VERSION"

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

systemctl daemon-reload

set +x
if [[ `docker info 2>&1 |grep cgroup -i` ]]; then
    if [[ `docker info 2>&1 |grep cgroup -c` -eq 1 ]]; then
        # we need restart, because of we are changing cgroupsdriver
        systemctl restart docker
    fi;
else
    systemctl start docker
fi;
set -x

##########################################
echo "Installing Kubernetes binaries"
##########################################
# vagrant fix vars
kubernetes_version="1.15.4"

KUBERNETES_PACKAGE_VERSION="${kubernetes_version}-00"

apt-get install -yq --no-install-recommends \
    apt-transport-https \
    curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update -qq

apt-get install -yq --no-install-recommends \
    kubelet="$KUBERNETES_PACKAGE_VERSION" \
    kubeadm="$KUBERNETES_PACKAGE_VERSION" \
    kubectl="$KUBERNETES_PACKAGE_VERSION"
apt-mark hold kubelet kubeadm kubectl

systemctl daemon-reload
