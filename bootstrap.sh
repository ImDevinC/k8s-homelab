#!/bin/bash

# This file helps create the initial setup of the homelab cluster and should only need to be ran 
# the first time the cluster is being configured.

install_argo() {
    local version=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/$version/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
}

command -v kubeadm > /dev/null 2>&1 || {
    echo "missing kubeadm"
    exit 1
}

command -v kubectl > /dev/null 2>&1 || {
    echo "missing kubectl"
    exit 1
}

command -v kubelet > /dev/null 2>&1 || {
    echo "missing kubelet"
    exit 1
}

command -v helm > /dev/null 2>&1 || {
    echo "missing helm"
    exit 1
}

command -v argocd > /dev/null 2>&1 || {
    install_argo
}

echo "initializing kubernetes cluster"
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "install flannel"
kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml

echo "install argo"
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd --create-namespace -n argo --values argo-values.yaml
password=$(kubectl -n argo get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login --username admin --password $password
argocd repo add https://github.com/imdevinc/k8s-homelab