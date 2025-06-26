#!/bin/bash

set -e

echo "[INFO] Installing K3s with Traefik..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=192.168.56.110 --flannel-iface=enp0s8 --write-kubeconfig-mode 644" sh -

echo "[INFO] Waiting for K3s server to be active..."
until systemctl is-active --quiet k3s; do
    sleep 2
done

echo "[INFO] Exporting KUBECONFIG..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "[INFO] Applying all settings in confs..."
kubectl apply -R -f /vagrant/confs/

echo "[INFO] Done! Apps are now reachable via Host headers."
echo "[INFO] Try: curl -H 'Host: app1.com' http://192.168.56.110"
echo "[INFO] Also try with 'app2.com' and 'app3.com' as host headers."
echo "[INFO] Finally, try a random host value, e.g. 'shmismshmang' - that should also go to app3."
