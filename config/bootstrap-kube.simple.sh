#!/bin/bash

ENABLE_SWAP=1
KUBEADM_PARAMS=""

if [[ "$ENABLE_SWAP" == "1" ]]; then
  KUBEADM_PARAMS="--ignore-preflight-errors=\"Swap\""
  mkswap /dev/sda2 && echo -e "#swap\n/dev/sda2\tnone\tswap\tsw\t0\t0\n\n" >> /etc/fstab && swapon -a
fi;

# TODO: Support dynamic ip ranges so 10.4 doesnt need to be hard coded.
LEAD_OCTETS=172.18.18
SERVER_IP=$(ip -f inet -o addr show | grep ${LEAD_OCTETS} | awk '{split($4,a,"/");print a[1]}')
apt-get install -y apt-transport-https

# We are running on 18.04 (bionic) but there is not currently a kubernetes repo for it. Using xenial for now.
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update

# https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/
# Ensure docker is installed
apt-get install -y docker.io jq
# Install k8s packages. kubelet will fail to start on the nodes until the master is configured.
apt-get install -y kubelet kubeadm kubectl kubernetes-cni ipvsadm || true
modprobe ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh

if [[ "$ENABLE_SWAP" == "1" ]]; then
  echo "KUBELET_EXTRA_ARGS=--node-ip=${SERVER_IP} --fail-swap-on=false" > /etc/default/kubelet
else
  echo "KUBELET_EXTRA_ARGS=--node-ip=${SERVER_IP} " > /etc/default/kubelet
fi;

systemctl enable docker
systemctl start docker

hostnameMatches() {
  hostname | grep $1 > /dev/null
  return $?
}

# Prevent swap error messages from stopping the provisioning
#swapoff -a

# TODO: Make work with multiple masters.
if hostnameMatches master1; then
  # TODO: dynamically pull k8s-master1 address instead of hard coded.
  kubeadm init --apiserver-advertise-address=172.18.18.100 --pod-network-cidr=10.244.0.0/16 $KUBEADM_PARAMS
  mkdir -p $HOME/.kube
  cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config
  # Install kube-router networking.
  #KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml
  KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
  # If you add nodes later you will need to get a new kubeadm token. Just run the following command on k8s-master1 before the vagrant up of a new node.
  kubeadm token create --print-join-command > /vagrant/config/kube-join.sh
  if [[ "$ENABLE_SWAP" == "1" ]]; then
    kube_join=$(tr -d '\n' < /vagrant/config/kube-join.sh)
    echo "${kube_join} --ignore-preflight-errors=\"Swap\" " > /vagrant/config/kube-join.sh
  fi;
  #kubectl create -f config/nginx/nginx-deployment.yaml
fi

if hostnameMatches node; then
  while [ ! -f /vagrant/config/kube-join.sh ]; do
    echo "Kubernetes master is not yet ready"
    sleep 3
  done
  echo "Kubernetes master is ready. Proceeding to join the cluster."
  sleep 60
  sh /vagrant/config/kube-join.sh
fi
