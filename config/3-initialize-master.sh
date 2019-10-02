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
cluster_name='k8s-test'
kubernetes_version="1.15.4"
pod_cidr="172.18.136.0/24"
service_cidr="172.18.137.0/24"
cluster_name_short="k8s-test"

# vagrant fix
apt-get install -yq --no-install-recommends \
    etcd-client

# vagrant fix
#export PATH="$PATH:/opt/bin"etcd-client
#export VAULT_ADDR="https://vault.mgit.cz:8200"

NODE_LABELS=("node-role.kubernetes.io/master=true")

set +x
REGION="Prague"
AVAILABILITY_ZONE="DC1"
# ifconfig is not installed
#IPV4="$(ip -f inet a s ens1f0np0 | grep inet | awk '{print $2}' | cut -d'/' -f1)"
# vagrant fix
IPV4="$(ip -f inet a s eth1 | grep inet | awk '{print $2}' | cut -d'/' -f1)"

if [[ "$IPV4" = "10.222."* ]]; then
    AVAILABILITY_ZONE="DC2"
fi

LAST_OCTET="$${IPV4##*.}"
if [[ "$AVAILABILITY_ZONE" == "DC1" ]]; then
    ADVERTISE_ADDRESS="10.221.0.$(( 100 + LAST_OCTET ))"
else
    ADVERTISE_ADDRESS="10.222.0.$LAST_OCTET"
fi

# vagrant fix
ADVERTISE_ADDRESS="172.18.18.100"

echo "ADVERTISE_ADDRESS: $ADVERTISE_ADDRESS"

INSTANCE_TYPE="$(sudo lshw -json -quiet| jq -r '.product' | tr -c 'a-zA-Z0-9' '-' | sed -e 's/--*/-/g' -e 's/-*-$//g' -e 's/^--*//g')"
set -x

NODE_LABELS+=("beta.kubernetes.io/instance-type=$INSTANCE_TYPE")
NODE_LABELS+=("failure-domain.beta.kubernetes.io/region=$REGION")
NODE_LABELS+=("failure-domain.beta.kubernetes.io/zone=$REGION-$AVAILABILITY_ZONE")

NODE_LABELS_STR="$(IFS=","; echo "$${NODE_LABELS[*]}")"

# fix CNI default plugin (temporary added dummy)
# https://github.com/containernetworking/plugins/tree/master/plugins/ipam/host-local
function create-temp-cni-plugin() {
    cat <<'EOF' > /etc/cni/net.d/10-calico.conflist
{
        "cniVersion": "0.3.1",
        "name": "mynet",
        "plugins": [
                {
                        "type": "ptp",
                        "ipMasq": true,
                        "ipam": {
                                "type": "host-local",
                                "subnet": "172.16.30.0/24",
                                "routes": [
                                        {
                                                "dst": "0.0.0.0/0"
                                        }
                                ]
                        }
                },
                {
                        "type": "portmap",
                        "capabilities": {"portMappings": true},
                        "externalSetMarkChain": "KUBE-MARK-MASQ"
                }
        ]
}
EOF

    systemctl restart kubelet
    sleep 30
}

mkdir -p /etc/cni/net.d

if [ ! -s /etc/cni/net.d/10-calico.conflist ]
then
    create-temp-cni-plugin
fi

function config-init() {
    cat <<'EOF' > /etc/ssl/certs/consul-proxy-ca.pem
-----BEGIN CERTIFICATE-----
MIIFDDCCA/SgAwIBAgIJAMO0l+sMIYAcMA0GCSqGSIb3DQEBBQUAMIG0MQswCQYD
VQQGEwJDWjEXMBUGA1UECBMOQ3plY2ggUmVwdWJsaWMxDzANBgNVBAcTBlByYWd1
ZTEaMBgGA1UEChMRTmV0cmV0YWlsIEhvbGRpbmcxFjAUBgNVBAsTDUlUIE9wZXJh
dGlvbnMxHTAbBgNVBAMTFE5ldHJldGFpbCBIb2xkaW5nIENBMSgwJgYJKoZIhvcN
AQkBFhlpdC5oZWxwZGVza0BucmhvbGRpbmcuY29tMB4XDTEzMDcwMzE0MzU0NloX
DTI0MDkxOTE0MzU0NlowgbQxCzAJBgNVBAYTAkNaMRcwFQYDVQQIEw5DemVjaCBS
ZXB1YmxpYzEPMA0GA1UEBxMGUHJhZ3VlMRowGAYDVQQKExFOZXRyZXRhaWwgSG9s
ZGluZzEWMBQGA1UECxMNSVQgT3BlcmF0aW9uczEdMBsGA1UEAxMUTmV0cmV0YWls
IEhvbGRpbmcgQ0ExKDAmBgkqhkiG9w0BCQEWGWl0LmhlbHBkZXNrQG5yaG9sZGlu
Zy5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCyeMsxhpbIiYz0
OK+7i06OqZ/vOTtOsxvavMufle7ZEYBJ5KjT2+Bzc6/qWh0BddMLtzMjkQ/TKxDB
wOqA+OZiMRmCdF1K7R9EqrQ8gim33JMss/hfhhgoQfFjan/wISMRdE3nN3mA28Hh
Lu2hmSWfKXyx4QQnmpB4VwRePnJCaTqbQVA+UHah485VnlXXMlXvyWumW7CcYo4z
7JRu7XILbFo+g1glr1lMhP3LRsoQEvp9jD0B8TgaAZlb1n4hJp+pyGenGH770GlS
LOgAEY1tNCsu3fRnMVsvfDf6RsG/JsgIiPQ8xVg0SI/BhWUdAtfyuPNui+twbTxX
x41UGViBAgMBAAGjggEdMIIBGTAdBgNVHQ4EFgQU3FQCGXPainaOueQFHTEHXHYu
EawwgekGA1UdIwSB4TCB3oAU3FQCGXPainaOueQFHTEHXHYuEayhgbqkgbcwgbQx
CzAJBgNVBAYTAkNaMRcwFQYDVQQIEw5DemVjaCBSZXB1YmxpYzEPMA0GA1UEBxMG
UHJhZ3VlMRowGAYDVQQKExFOZXRyZXRhaWwgSG9sZGluZzEWMBQGA1UECxMNSVQg
T3BlcmF0aW9uczEdMBsGA1UEAxMUTmV0cmV0YWlsIEhvbGRpbmcgQ0ExKDAmBgkq
hkiG9w0BCQEWGWl0LmhlbHBkZXNrQG5yaG9sZGluZy5jb22CCQDDtJfrDCGAHDAM
BgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBBQUAA4IBAQBtE2vawXVkuCfzz0dqre7Y
RVE16I7g65p0N7n8B1EQtfjAInKZ/fwPJ+jpEB6Jx6CeXrk4jO7Kp21Sp7p5JDlG
txIro8zJCaCKCwXK3I7gGO0kAGhUXq74Jq3PpRqsM0TeN1I0rgHYT9f0uGO+G1Sg
blZCilW9ji2NZhqa5TqtTA26RDNwr3eLqRrp8lb3YvBB7j+JAxvkQam3/H/sXSGd
jlRvtKSxxKjKfluysKHpoy9gLS9zKe2WzmBNy2JeRPSSTA7zvx/v7GJkXg5fBcOD
P9Njbdwd855vQ6h4z+ViE9hBoaJiy8SaHZ/TaO2gJIlFAgy0htGVYCDOd31xsNAR
-----END CERTIFICATE-----
EOF

    cat <<YAML > kubeadm-config-init.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: ${kubernetes_version}
controlPlaneEndpoint: "172.18.18.100:6443"
clusterName: ${cluster_name}
networking:
  dnsDomain: ${cluster_name}.local
  podSubnet: ${pod_cidr}
  serviceSubnet: ${service_cidr}
dns:
  type: CoreDNS
apiServer:
  certSANs:
    - "$ADVERTISE_ADDRESS"
    - "apiserver.${cluster_name}.cc.mgit.cz"
  extraArgs:
    audit-dynamic-configuration: "true"
    feature-gates: DynamicAuditing=true
    runtime-config: auditregistration.k8s.io/v1alpha1=true
    stderrthreshold: "3"
    #oidc-issuer-url: https://172.18.18.100:4443/
    #oidc-client-id: dex-k8s-authenticator
    #oidc-ca-file: /etc/ssl/certs/consul-proxy-ca.pem
    #oidc-username-claim: email
    #oidc-groups-claim: groups
etcd:
  local:
    serverCertSANs:
      - "$IPV4"
      - "$ADVERTISE_ADDRESS"
    peerCertSANs:
      - "$IPV4"
      - "$ADVERTISE_ADDRESS"
    extraArgs:
      listen-metrics-urls: "http://0.0.0.0:9200"
      listen-client-urls: "https://0.0.0.0:2379"
      listen-peer-urls: "https://0.0.0.0:2380"
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
nodeRegistration:
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
  kubeletExtraArgs:
    node-labels: "'$NODE_LABELS_STR'"
    node-ip: "$ADVERTISE_ADDRESS"
localAPIEndpoint:
  advertiseAddress: "$ADVERTISE_ADDRESS"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
maxPods: 500
podCIDR: ${pod_cidr}
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
featureGates:
  SupportIPVSProxyMode: true
mode: ipvs
YAML
}

function init-cluster() {
    kubeadm init --config=kubeadm-config-init.yaml --upload-certs -v=10

    #vagrant fix
    cat /etc/kubernetes/admin.conf
    #cat /etc/kubernetes/admin.conf | \
    #    vault write "secret/cc/kubeadm/${cluster_name}/kubeconfig" data=-

    #vagrant fix
    kubeadm token create --ttl=0
    #kubeadm token create --ttl=0 | \
    #    vault write "secret/cc/kubeadm/${cluster_name}/join" token=-

    #vagrant fix
    kubeadm token create --print-join-command | grep -E --only-matching --color=never 'sha256:.*'
    #kubeadm token create --print-join-command | grep -E --only-matching --color=never 'sha256:.*' | \
    #    vault write "secret/cc/kubeadm/${cluster_name}/discovery" hash=-

    #vagrant fix
    #cat /etc/kubernetes/pki/ca.crt | \
    #    vault write "secret/cc/kubeadm/${cluster_name}/ca" cert=-

    # The next step randomly fails if run too soon
    sleep 10
    kubeadm init phase upload-certs --upload-certs | \
        tail -n1 | \
        vault write "secret/cc/kubeadm/${cluster_name}/cert-store" key=-
}

function join-cluster() {
    JOIN_TOKEN="$(vault read "secret/cc/kubeadm/${cluster_name}/join" -format=json | jq -r '.data.token')"
    CA_HASH="$(vault read "secret/cc/kubeadm/${cluster_name}/discovery" -format=json | jq -r '.data.hash')"
    CERT_STORE_KEY="$(vault read "secret/cc/kubeadm/${cluster_name}/cert-store" -format=json | jq -r '.data.key')"

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
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
  kubeletExtraArgs:
    node-labels: "$NODE_LABELS_STR"
controlPlane:
  localAPIEndpoint:
    advertiseAddress: "$ADVERTISE_ADDRESS"
    bindPort: 6443
  certificateKey: "$CERT_STORE_KEY"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
maxPods: 500
YAML

    kubeadm join --config=kubeadm-config.yaml -v=10
}

function reload-configs() {
    echo "Updating in-cluster kubeadm config"
    config-init
    kubeadm init phase kubelet-start --config kubeadm-config-init.yaml
    # The next step randomly fails if run too soon (because of restart kubelet)
    sleep 40
    kubeadm config upload from-file --config kubeadm-config-init.yaml
    kubeadm init phase upload-config kubelet --config kubeadm-config-init.yaml

    rm /etc/kubernetes/pki/etcd/peer.crt /etc/kubernetes/pki/etcd/peer.key /etc/kubernetes/pki/etcd/server.crt /etc/kubernetes/pki/etcd/server.key
    kubeadm init phase certs etcd-peer --config kubeadm-config-init.yaml
    kubeadm init phase certs etcd-server --config kubeadm-config-init.yaml
    kubeadm init phase etcd local --config kubeadm-config-init.yaml

    kubeadm upgrade diff "${kubernetes_version}" --config kubeadm-config-init.yaml
    kubeadm upgrade apply "${kubernetes_version}" --yes
    systemctl daemon-reload
    systemctl restart kubelet
    echo "In-cluster kubeadm config updated"
}


# fixes https://github.com/kubernetes/kubeadm/issues/1345
mkdir -p /etc/kubernetes/manifests

if [[ -e /etc/kubernetes/admin.conf ]]; then
    echo "Found pre-existing kubeconfig, will only reload configuration"
    reload-configs

elif vault read "secret/cc/kubeadm/${cluster_name}/join" >/dev/null; then
    echo "Configuration found, joining pre-existing cluster"
    echo "If this is not desired and you want to replace the existing cluster,"
    echo "remove all Vault keys under 'secret/cc/kubeadm/${cluster_name}'."
    join-cluster

    sleep 30 # TODO
    reload-configs

else
    echo "No configuration found, will create new cluster."
    echo "All credentials will be saved to 'secret/cc/kubeadm/${cluster_name}'."
    config-init
    init-cluster
fi
