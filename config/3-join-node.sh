#!/usr/bin/env bash
set -euxo pipefail
IFS=$'\n\t'
DIR="$( cd "$( dirname "$${BASH_SOURCE[0]}" )" && pwd )"

if [[ $UID -ne 0 ]]; then
    echo "Restarting script as root"
    sudo bash "$0" "$@"
    exit $?
fi

# vagrant fix
# export PATH="$PATH:/opt/bin"
# export VAULT_ADDR="https://vault.mgit.cz:8200"

# vagrant fix
#JOIN_TOKEN="$(vault read "secret/cc/kubeadm/${cluster_name}/join" -format=json | jq -r '.data.token')"
#CA_HASH="$(vault read "secret/cc/kubeadm/${cluster_name}/discovery" -format=json | jq -r '.data.hash')"

NODE_LABELS=("node-role.kubernetes.io/node=true")

REGION="Prague"
AVAILABILITY_ZONE="DC1"
IPV4="$(ip -f inet a s enp22s0f0 | grep inet | awk '{print $2}' | cut -d'/' -f1)"
if [[ "$IPV4" = "10.222."* ]]; then
    AVAILABILITY_ZONE="DC2"
fi

if [[ "$AVAILABILITY_ZONE" == "DC1" ]]; then
    ADVERTISE_NET="10.221.0."
else
    ADVERTISE_NET="10.222.0."
fi

LAST_OCTET="$${IPV4##*.}"
ADVERTISE_OCTET="$LAST_OCTET"

# Change last octed based on Leaf number:
# - Leaf-003 and Leaf-004 means +100 to the last octet.
# - Rest Leafs means no changes in the last octet.
# Leaf-003 and Leaf-004 IPs:
LEAF3_4=( 10.221.253.* 10.221.252.* 10.222.253.* 10.222.252.* )
for LEAF_PREFIX in "$${LEAF3_4[@]}"; do
    if [[ "$IPV4" = $LEAF_PREFIX ]]; then
        ADVERTISE_OCTET="$(( 100 + LAST_OCTET ))"
        break
    fi
done

ADVERTISE_ADDRESS="$${ADVERTISE_NET}$${ADVERTISE_OCTET}"

INSTANCE_TYPE="$(sudo lshw -json | jq -r '.product' | tr -c 'a-zA-Z0-9' '-' | sed -e 's/--*/-/g' -e 's/-*-$//g' -e 's/^--*//g')"

NODE_LABELS+=("beta.kubernetes.io/instance-type=$INSTANCE_TYPE")
NODE_LABELS+=("failure-domain.beta.kubernetes.io/region=$REGION")
NODE_LABELS+=("failure-domain.beta.kubernetes.io/zone=$REGION-$AVAILABILITY_ZONE")

NODE_LABELS_STR="$(IFS=","; echo "$${NODE_LABELS[*]}")"

cat <<YAML > kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: "172.18.18.100:6443"
    token: $JOIN_TOKEN
    unsafeSkipCAVerification: false
    caCertHashes:
      - $CA_HASH
  timeout: 5m0s
  tlsBootstrapToken: $JOIN_TOKEN
nodeRegistration:
  kubeletExtraArgs:
    node-labels: "'$NODE_LABELS_STR'"
    node-ip: "$ADVERTISE_ADDRESS"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
maxPods: 500
YAML

# fixes https://github.com/kubernetes/kubeadm/issues/1345
mkdir -p /etc/kubernetes/manifests

if [[ -e /etc/kubernetes/kubelet.conf ]]; then
    echo "Found pre-existing kubeconfig, will only reload configuration"
    kubeadm join phase kubelet-start --config=kubeadm-config.yaml
    systemctl daemon-reload
    systemctl restart kubelet

else
    echo "Configuration not found, joining pre-existing cluster"
    kubeadm join --config=kubeadm-config.yaml
fi
